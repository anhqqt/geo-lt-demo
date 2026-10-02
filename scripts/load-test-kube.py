"""Bound Kubernetes requests and track UID-based ownership."""

import json
import os
import subprocess
import time

RESOURCES = {"TestRun": "testruns.k6.io", "ConfigMap": "configmaps", "Job": "jobs.batch", "Pod": "pods", "Service": "services"}
PATHS = {"TestRun": "/apis/k6.io/v1alpha1", "Job": "/apis/batch/v1", "ConfigMap": "/api/v1", "Pod": "/api/v1", "Service": "/api/v1"}


class KubeError(RuntimeError):
    pass


class Kube:
    def __init__(self, namespace, context=None, clock=time.monotonic):
        self.namespace = namespace
        self.context = context or os.environ.get("KUBE_CONTEXT")
        if not self.context:
            raise ValueError("Set KUBE_CONTEXT to an explicitly verified cluster context")
        self.clock = clock

    def call(self, args, deadline, body=None, missing=False):
        remaining = deadline - self.clock()
        if remaining <= 0:
            raise KubeError("Kubernetes operation deadline reached")
        budget = min(20, remaining)
        command = ["kubectl", "--context", self.context, "--namespace", self.namespace,
                   "--request-timeout", f"{max(1, int(budget))}s", *args]
        try:
            result = subprocess.run(command, input=json.dumps(body) if body is not None else None,
                                    capture_output=True, text=True, timeout=budget)
        except subprocess.TimeoutExpired as error:
            raise KubeError("Kubernetes request timed out; creation may require reconciliation") from error
        if result.returncode:
            if missing and "(NotFound)" in result.stderr:
                return None
            # API diagnostics may include submitted workload content. Keep those out of workflow logs.
            reason = "UID conflict" if "Conflict" in result.stderr else "Kubernetes request failed"
            raise KubeError(reason + ": " + args[0])
        return json.loads(result.stdout) if result.stdout.strip().startswith(("{", "[")) else result.stdout.strip()

    def get(self, kind, name, deadline):
        return self.call(["get", RESOURCES[kind], name, "-o", "json"], deadline, missing=True)

    def inventory(self, deadline):
        objects = []
        for resource in RESOURCES.values():
            objects.extend(self.call(["get", resource, "-o", "json"], deadline)["items"])
        return objects

    def delete(self, obj, deadline):
        kind, name, uid = obj["kind"], obj["name"], obj["uid"]
        plural = RESOURCES[kind].split(".")[0]
        path = f"{PATHS[kind]}/namespaces/{self.namespace}/{plural}/{name}"
        return self.call(["delete", "--raw", path, "-f", "-"], deadline,
                         {"apiVersion": "v1", "kind": "DeleteOptions", "preconditions": {"uid": uid},
                          "propagationPolicy": "Foreground", "gracePeriodSeconds": 0}, missing=True)

    def preflight(self, deadline):
        for kind in RESOURCES:
            for verb in (["get", "list", "create", "delete"] if kind in ("TestRun", "ConfigMap") else ["get", "list", "delete"]):
                if self.call(["auth", "can-i", verb, RESOURCES[kind]], deadline) != "yes":
                    raise KubeError("Missing scoped permission: " + verb + " " + kind)
        self.inventory(deadline)


def identity(obj):
    m = obj["metadata"]
    return {"kind": obj["kind"], "name": m["name"], "uid": m["uid"],
            "owner_uids": [r["uid"] for r in m.get("ownerReferences", [])]}


def discover(record, objects):
    known = {o["uid"]: o for o in record.get("objects", [])}
    known.update({o["uid"]: o for o in record["roots"] if o.get("uid")})
    changed = True
    while changed:
        changed = False
        for obj in objects:
            item = identity(obj)
            if item["uid"] in known or not any(uid in known for uid in item["owner_uids"]):
                continue
            tag = obj["metadata"].get("labels", {}).get("load-test/run-id")
            if tag is not None and tag != record["run_id"]:
                raise KubeError("Owner-linked object has a conflicting run label")
            known[item["uid"]] = item
            changed = True
    record["objects"] = list(known.values())
    return [o for o in objects if o["metadata"]["uid"] in known]


def terminal(job):
    conditions = {c["type"] for c in job.get("status", {}).get("conditions", []) if c.get("status") == "True"}
    if "Failed" in conditions:
        return "failed"
    return "succeeded" if "Complete" in conditions else "pending"


def runners(record, objects):
    root = next(root for root in record["roots"] if root["kind"] == "TestRun")
    jobs = [o for o in objects if o["kind"] == "Job"]
    counts = dict(expected=len(record["expected_runners"]), succeeded=0, failed=0, missing=0, pending=0)
    for name in record["expected_runners"]:
        matches = [o for o in jobs if o["metadata"]["name"] == name]
        if not matches:
            counts["missing"] += 1
            continue
        if len(matches) != 1:
            raise KubeError("Duplicate expected runner identity")
        obj = matches[0]
        m = obj["metadata"]
        if root.get("uid") not in [r["uid"] for r in m.get("ownerReferences", [])]:
            raise KubeError("Expected runner has a different owner UID")
        if any(m.get("labels", {}).get(k) != v for k, v in {"app": "k6", "runner": "true", "k6_cr": root["name"]}.items()):
            raise KubeError("Expected runner labels differ from the pinned Operator")
        prior = record.setdefault("runner_uids", {}).setdefault(name, m["uid"])
        if prior != m["uid"]:
            raise KubeError("Expected runner UID was replaced")
        counts[terminal(obj)] += 1
    return counts
