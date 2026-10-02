#!/usr/bin/env python3
"""Manage run identities, observation, reporting and cleanup."""

import argparse
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import runpy
import signal
import sys
import time
import uuid

C = runpy.run_path(str(Path(__file__).with_name("load-test-common.py")))
ROOTS = {"ConfigMap": ("v1", "k6-script-"), "TestRun": ("k6.io/v1alpha1", "k6-")}


def utc():
    return datetime.now(timezone.utc).isoformat()


def finalization_deadline(record, clock=time.monotonic):
    if "finalization_deadline" not in record:
        record["finalization_deadline"] = min(clock() + 300, record["hard_deadline"] - 15)
        record["observation_cutoff"] = min(clock() + 60, record["finalization_deadline"] - 240)
    return record["finalization_deadline"]


def valid_uid(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", value)


def validate_record(record):
    K = C["module"]("load-test-kube")
    if not isinstance(record, dict) or not re.fullmatch(r"[1-9][0-9]{0,19}-[1-9][0-9]{0,9}", record.get("run_id", "")):
        raise ValueError("Invalid run record identity")
    C["dns_label"](record.get("namespace"))
    if not isinstance(record.get("context"), str) or not record["context"]:
        raise ValueError("Run record has no Kubernetes context")
    roots = record.get("roots")
    if not isinstance(roots, list) or not 1 <= len(roots) <= 2:
        raise ValueError("Run record must contain original root identities")
    kinds = set()
    for root in roots:
        if (not isinstance(root, dict) or root.get("kind") not in ROOTS
                or root["kind"] in kinds or root.get("name") != ROOTS[root["kind"]][1] + record["run_id"]
                or (root.get("uid") is not None and not valid_uid(root["uid"]))
                or ("attempted" in root and not isinstance(root["attempted"], bool))):
            raise ValueError("Invalid original root identity")
        kinds.add(root["kind"])
    objects = record.get("objects")
    if not isinstance(objects, list) or any(not isinstance(obj, dict) or obj.get("kind") not in K.RESOURCES
                                          or not isinstance(obj.get("name"), str) or not obj["name"]
                                          or not valid_uid(obj.get("uid")) for obj in objects):
        raise ValueError("Invalid recorded object identity")
    return record


def root_identity(record, root, obj):
    K = C["module"]("load-test-kube")
    metadata = obj.get("metadata", {}) if isinstance(obj, dict) else {}
    labels, annotations = metadata.get("labels", {}), metadata.get("annotations", {})
    expected = {"load-test/creation-token": record["creation_token"], "load-test/repository": record["repository"],
                "load-test/workflow-sha": record["workflow_sha"], "load-test/workload-sha": record["workload_sha"]}
    if (not isinstance(obj, dict) or obj.get("kind") != root["kind"] or obj.get("apiVersion") != ROOTS[root["kind"]][0]
            or metadata.get("name") != root["name"] or metadata.get("namespace") != record["namespace"]
            or not valid_uid(metadata.get("uid"))
            or any(annotations.get(key) != value for key, value in expected.items())
            or labels.get("load-test/run-id") != record["run_id"]
            or labels.get("app.kubernetes.io/managed-by") != "load-test-workflow"):
        raise K.KubeError("Root server identity differs from this run; object preserved")
    return metadata["uid"]


def reconcile(record, kube, deadline, objects=None):
    for root in record["roots"]:
        if root.get("uid") or not root.get("attempted"):
            continue
        if objects is None:
            obj = kube.get(root["kind"], root["name"], deadline)
        else:
            obj = next((item for item in objects if item["kind"] == root["kind"]
                        and item["metadata"]["name"] == root["name"]), None)
        if obj is not None:
            root["uid"] = root_identity(record, root, obj)


def prepare(request, timing, record_path, context=None, kube=None, clock=time.monotonic, runtime=None):
    K = C["module"]("load-test-kube")
    if Path(record_path).exists():
        raise ValueError("A run record already exists; use cleanup or recovery without replaying load")
    if request.get("validation_status") != "accepted":
        raise ValueError("An accepted request is required")
    if not re.fullmatch(r"[1-9][0-9]{0,19}-[1-9][0-9]{0,9}", request["run_id"]):
        raise ValueError("Invalid run identity")
    runtime = C["runtime_config"](C["runtime_from_env"]() if runtime is None else runtime)
    if request["repository"] != runtime["repository"]:
        raise ValueError("Request repository differs from runtime configuration")
    namespace = runtime["runner_namespace"]
    kube = kube or K.Kube(namespace, context, clock)
    start_time = timing["job_start_monotonic"]
    if not 0 <= clock() - start_time < 900:
        raise ValueError("Preparation budget expired or timing is invalid")
    record = {**{key: request[key] for key in ("run_id", "repository", "workflow_sha", "workload_sha")},
              "namespace": namespace, "context": kube.context, "creation_token": str(uuid.uuid4()), "prepared": False,
              "job_start_utc": timing["job_start_utc"], "preparation_deadline": start_time + 900,
              "hard_deadline": start_time + request["job_timeout_minutes"] * 60,
              "roots": [{"kind": kind, "name": prefix + request["run_id"], "uid": None, "attempted": False}
                        for kind, (_, prefix) in ROOTS.items()], "objects": [],
              "expected_runners": [f"k6-{request['run_id']}-{i}" for i in range(1, request["runners"] + 1)]}
    C["write"](record_path, record)
    deadline = record["preparation_deadline"]
    kube.preflight(deadline)
    for root in record["roots"]:
        if kube.get(root["kind"], root["name"], deadline) is not None:
            raise K.KubeError("Run root already exists; refusing to adopt or replay it")
    record["prepared"] = True
    C["write"](record_path, record)
    return record


def selected_root(record, kind):
    validate_record(record)
    matches = [root for root in record["roots"] if root["kind"] == kind]
    if len(matches) != 1:
        raise ValueError("Root kind is not in the run record")
    return matches[0]


def attempt(record_path, kind, kube=None, clock=time.monotonic):
    K = C["module"]("load-test-kube")
    record = C["read"](record_path)
    root = selected_root(record, kind)
    if not record.get("prepared") or root.get("attempted") or root.get("uid"):
        raise ValueError("Root creation is unprepared or already attempted; do not replay load")
    if kind == "TestRun" and not selected_root(record, "ConfigMap").get("uid"):
        raise ValueError("Register the ConfigMap before creating the TestRun")
    deadline = min(record["preparation_deadline"], record["hard_deadline"] - 315)
    if deadline - clock() < 1:
        raise K.KubeError("Preparation deadline reached before root creation")
    kube = kube or K.Kube(record["namespace"], record["context"], clock)
    if kube.get(kind, root["name"], deadline) is not None:
        raise K.KubeError("Run root already exists; refusing to adopt or replay it")
    budget = int(min(20, deadline - clock()))
    if budget < 1:
        raise K.KubeError("Preparation deadline reached before root creation")
    root["attempted"] = True
    C["write"](record_path, record)
    return budget


def register(record_path, kind, created):
    record = C["read"](record_path)
    root = selected_root(record, kind)
    if not root.get("attempted") or root.get("uid"):
        raise ValueError("Register only an attempted root without a recorded UID")
    root["uid"] = root_identity(record, root, created)
    C["write"](record_path, record)
    print(f"Recovery identity: run={record['run_id']} namespace={record['namespace']} {kind}={root['name']} uid={root['uid']}", flush=True)
    return record


def ready(record, request):
    validate_record(record)
    if (request.get("validation_status") != "accepted" or not record.get("prepared")
            or any(record.get(key) != request.get(key) for key in ("run_id", "repository", "workflow_sha", "workload_sha"))
            or {root["kind"] for root in record["roots"]} != set(ROOTS)
            or any(not root.get("attempted") or not valid_uid(root.get("uid")) for root in record["roots"])):
        raise ValueError("Both original roots must be registered before observation")


def observe(request, record_path, outcome_path, kube=None, clock=time.monotonic, sleep=time.sleep):
    K = C["module"]("load-test-kube")
    record = C["read"](record_path)
    kube = kube or K.Kube(record["namespace"], record["context"], clock)
    outcome = {"execution_status": "pending", "cleanup_status": "unknown", "known_incomplete_data": [
        "Metric completeness is not reconciled automatically; inspect Grafana for missing data."],
        "measurement_start": None, "measurement_end": None, "interval_precision": "load start not observed"}
    observed_failure = False
    try:
        while True:
            if "load_deadline" in record and clock() >= record["load_deadline"]:
                finalization_deadline(record, clock)
            if "load_deadline" not in record and clock() >= record["preparation_deadline"]:
                outcome.update(execution_status="timed_out", reason="Preparation/startup exceeded 15 minutes")
                break
            if "observation_cutoff" in record and clock() >= record["observation_cutoff"]:
                outcome.update(execution_status="failed" if observed_failure else "incomplete", reason="Runner outcomes incomplete at final observation cutoff")
                break
            deadline = record.get("observation_cutoff", record.get("load_deadline", record["preparation_deadline"]))
            objects = kube.inventory(deadline)
            owned = K.discover(record, objects)
            counts = K.runners(record, objects)
            outcome.update(counts)
            observed_failure |= counts["failed"] > 0
            root_name = "k6-" + record["run_id"]
            helpers = {o["metadata"]["name"]: o for o in owned if o["kind"] == "Job" and o["metadata"]["name"] not in record["expected_runners"]}
            if any(K.terminal(j) == "failed" for j in helpers.values()):
                outcome.update(execution_status="failed", reason="Initializer or starter Job failed")
                break
            starter = helpers.get(root_name + "-starter")
            if "load_deadline" not in record and starter and K.terminal(starter) == "succeeded" and not counts["missing"]:
                # The starter shell can mask an HTTP start error; terminal runner Jobs still decide success.
                completion = starter.get("status", {}).get("completionTime")
                if completion:
                    elapsed = max(0, time.time() - datetime.fromisoformat(completion.replace("Z", "+00:00")).timestamp())
                else:
                    completion, elapsed = utc(), 0
                record["load_deadline"] = min(clock() - elapsed + request["duration_seconds"] + 30, record["hard_deadline"] - 315)
                outcome.update(measurement_start=completion, interval_precision="estimated from starter command completion; runner start is not individually proven")
            if counts["succeeded"] + counts["failed"] == counts["expected"]:
                if not observed_failure and "load_deadline" not in record:
                    outcome.update(execution_status="incomplete", reason="Runner completion lacks successful starter evidence")
                else:
                    outcome.update(execution_status="failed" if observed_failure else "succeeded", reason="All expected runner Jobs reached terminal conditions")
                break
            if "load_deadline" not in record and clock() >= record["preparation_deadline"]:
                outcome.update(execution_status="timed_out", reason="Preparation/startup exceeded 15 minutes")
                break
            if "load_deadline" in record and clock() >= record["load_deadline"]:
                finalization_deadline(record, clock)
                if clock() >= record["observation_cutoff"]:
                    outcome.update(execution_status="failed" if observed_failure else "incomplete", reason="Runner outcomes incomplete at final observation cutoff")
                    break
            C["write"](record_path, record)
            C["write"](outcome_path, outcome)
            next_deadline = record.get("observation_cutoff", record.get("load_deadline", record["preparation_deadline"]))
            sleep(max(0.01, min(5, next_deadline - clock())))
    except K.KubeError as error:
        outcome.update(execution_status="failed" if observed_failure else "incomplete", reason=str(error))
    finally:
        finalization_deadline(record, clock)
        outcome["measurement_end"] = utc()
        if not outcome["measurement_start"]:
            outcome["known_incomplete_data"].append("No load-start boundary was established")
        C["write"](record_path, record)
        C["write"](outcome_path, outcome)
    return outcome


def cleanup(record_path, outcome_path, kube=None, clock=time.monotonic, sleep=time.sleep):
    K = C["module"]("load-test-kube")
    outcome = C["read"](outcome_path, {"execution_status": "incomplete"})
    if not Path(record_path).exists():
        outcome.update(cleanup_status="unknown", cleanup_error="Run record unavailable; inspect original identities before recovery", remaining=[])
        C["write"](outcome_path, outcome)
        return outcome
    record = validate_record(C["read"](record_path))
    if not record["objects"] and all(not root.get("attempted") and not root.get("uid") for root in record["roots"]):
        outcome.update(cleanup_status="not_needed", remaining=[])
        C["write"](outcome_path, outcome)
        return outcome
    kube = kube or K.Kube(record["namespace"], record["context"], clock)
    deadline = finalization_deadline(record, clock)
    C["write"](record_path, record)
    empty_snapshots = 0
    remaining = []
    try:
        while clock() < deadline:
            objects = kube.inventory(deadline)
            reconcile(record, kube, deadline, objects)
            K.discover(record, objects)
            unresolved = [root for root in record["roots"] if root.get("attempted") and not root.get("uid")]
            current = {(o["kind"], o["metadata"]["name"]): o for o in objects}
            targets = {o["uid"]: o for o in record["objects"]}
            targets.update({o["uid"]: o for o in record["roots"] if o.get("uid")})
            remaining = []
            for obj in targets.values():
                live = current.get((obj["kind"], obj["name"]))
                if live is None:
                    continue
                if live["metadata"]["uid"] != obj["uid"]:
                    raise K.KubeError("Recorded object name was replaced; replacement preserved")
                remaining.append(obj)
            C["write"](record_path, record)
            if not remaining and not unresolved:
                empty_snapshots += 1
                if empty_snapshots >= 2:
                    outcome.update(cleanup_status="verified", remaining=[])
                    C["write"](outcome_path, outcome)
                    return outcome
            else:
                empty_snapshots = 0
                order = {"TestRun": 0, "ConfigMap": 1, "Job": 2, "Service": 3, "Pod": 4}
                for obj in sorted(remaining, key=lambda item: order[item["kind"]]):
                    kube.delete(obj, deadline)
            sleep(min(3, max(0, deadline - clock())))
        unresolved = [root for root in record["roots"] if root.get("attempted") and not root.get("uid")]
        remaining.extend(unresolved)
        reason = "Uncertain creation remains unresolved" if unresolved else "Cleanup deadline expired"
        raise K.KubeError(reason)
    except K.KubeError as error:
        outcome.update(cleanup_status="failed", cleanup_error=str(error), remaining=remaining)
        C["write"](record_path, record)
        C["write"](outcome_path, outcome)
        return outcome


def recover(run_id, namespace, testrun_uid, configmap_uid, output, context=None):
    K = C["module"]("load-test-kube")
    if not re.fullmatch(r"[1-9][0-9]{0,19}-[1-9][0-9]{0,9}", run_id):
        raise ValueError("Invalid original run ID")
    C["dns_label"](namespace)
    if not (testrun_uid or configmap_uid):
        raise ValueError("Supply at least one original root UID")
    roots = []
    for kind, name, uid in (("TestRun", "k6-" + run_id, testrun_uid), ("ConfigMap", "k6-script-" + run_id, configmap_uid)):
        if uid:
            if not re.fullmatch(r"[0-9a-fA-F-]{36}", uid):
                raise ValueError("Invalid original UID")
            roots.append({"kind": kind, "name": name, "uid": uid})
    kube = K.Kube(namespace, context)
    record = {"run_id": run_id, "namespace": namespace, "context": kube.context, "roots": roots, "objects": [],
              "expected_runners": [], "hard_deadline": time.monotonic() + 315,
              "finalization_deadline": time.monotonic() + 300}
    record_path = str(output) + ".record.json"
    C["write"](record_path, record)
    C["write"](output, {"execution_status": "incomplete", "reason": "Cleanup-only recovery; original execution outcome retained in its GitHub run"})
    return cleanup(record_path, output, kube)


class Cancelled(Exception):
    pass


def current_outcome(path):
    try:
        value = C["read"](path, {})
        return value if isinstance(value, dict) else {}
    except (ValueError, OSError):
        return {}


def finalize(request_path, record_path, outcome_path, summary_path, workflow_status):
    def cancel(_signal, _frame):
        raise Cancelled("Cancellation received; cleanup requested")
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, cancel)
    summary_ok = True
    try:
        request = C["read"](request_path)
        if workflow_status not in ("success", "failure", "cancelled"):
            raise ValueError("Invalid prior workflow status")
        if workflow_status == "cancelled":
            raise Cancelled("Workflow cancelled before observation")
        if workflow_status == "failure":
            value = current_outcome(outcome_path)
            if value.get("execution_status") not in ("failed", "timed_out", "incomplete", "cancelled"):
                value.update(execution_status="failed", reason="Workflow preparation, creation or observation failed")
            C["write"](outcome_path, value)
        else:
            ready(C["read"](record_path), request)
            if current_outcome(outcome_path).get("execution_status") != "succeeded":
                raise ValueError("Successful runner observation is required before finalization")
    except Exception as error:
        value = current_outcome(outcome_path)
        status = "cancelled" if workflow_status == "cancelled" or isinstance(error, Cancelled) else "failed"
        value.update(execution_status=status, reason=str(error))
        C["write"](outcome_path, value)
    finally:
        # Repeated cooperative signals must not skip cleanup; forced runner loss needs recovery.
        for sig in (signal.SIGINT, signal.SIGTERM):
            signal.signal(sig, signal.SIG_IGN)
        try:
            C["module"]("load-test-summary").render(request_path, record_path, outcome_path, summary_path)
        except Exception:
            summary_ok = False
        try:
            cleanup(record_path, outcome_path)
        except Exception as error:
            value = current_outcome(outcome_path)
            value.setdefault("execution_status", "incomplete")
            value.update(cleanup_status="unknown", cleanup_error=str(error))
            C["write"](outcome_path, value)
        try:
            C["module"]("load-test-summary").render(request_path, record_path, outcome_path, summary_path)
        except Exception:
            summary_ok = False
    outcome = current_outcome(outcome_path)
    outcome["summary_status"] = "succeeded" if summary_ok else "failed"
    github_output = os.environ.get("GITHUB_OUTPUT")
    try:
        C["write"](outcome_path, outcome)
        if github_output and summary_ok:
            with open(github_output, "a") as stream:
                stream.write("summary_written=true\n")
    except Exception:
        summary_ok = False
        raise
    finally:
        if github_output and not summary_ok:
            Path(summary_path).write_text("")
    return 0 if summary_ok and outcome.get("execution_status") == "succeeded" and outcome.get("cleanup_status") == "verified" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command, names in {"prepare": ("request", "timing", "record"), "attempt": ("record",),
                           "register": ("record", "created"), "observe": ("request", "record", "outcome"),
                           "finalize": ("request", "record", "outcome", "summary"),
                           "cleanup": ("record", "outcome"), "recover": ("run-id", "namespace", "output")}.items():
        child = sub.add_parser(command)
        for name in names:
            child.add_argument("--" + name, required=True)
        if command in ("attempt", "register"):
            child.add_argument("--kind", choices=("ConfigMap", "TestRun"), required=True)
        if command == "finalize":
            child.add_argument("--workflow-status", choices=("success", "failure", "cancelled"), required=True)
        if command == "recover":
            child.add_argument("--testrun-uid")
            child.add_argument("--configmap-uid")
            child.add_argument("--context")
    args = parser.parse_args()
    if args.command == "finalize":
        return finalize(args.request, args.record, args.outcome, args.summary, args.workflow_status)
    if args.command == "prepare":
        prepare(C["read"](args.request), C["read"](args.timing), args.record)
        return 0
    if args.command == "attempt":
        print(attempt(args.record, args.kind))
        return 0
    if args.command == "register":
        register(args.record, args.kind, C["read"](args.created))
        return 0
    if args.command == "observe":
        request = C["read"](args.request)
        ready(C["read"](args.record), request)
        value = observe(request, args.record, args.outcome)
        return 0 if value["execution_status"] == "succeeded" else 1
    value = (cleanup(args.record, args.outcome) if args.command == "cleanup" else
             recover(args.run_id, args.namespace, args.testrun_uid, args.configmap_uid, args.output, args.context))
    return 0 if value["cleanup_status"] in ("verified", "not_needed") else 1


if __name__ == "__main__":
    sys.exit(main())
