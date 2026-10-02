#!/usr/bin/env python3
"""Verify scoped permissions and fresh exec tokens after 15 minutes without creating objects."""

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import runpy
import subprocess
import time

C = runpy.run_path(str(Path(__file__).with_name("load-test-common.py")))
K = C["module"]("load-test-kube")


def verify(runtime, kube, deadline):
    kube.preflight(deadline)
    denied = [("create", "namespaces", None), ("create", "roles.rbac.authorization.k8s.io", runtime["runner_namespace"]),
              ("create", "rolebindings.rbac.authorization.k8s.io", runtime["runner_namespace"]),
              ("create", "serviceaccounts", runtime["runner_namespace"]), ("create", "pods", runtime["runner_namespace"]),
              ("create", "jobs.batch", runtime["runner_namespace"]), ("get", "secrets", runtime["runner_namespace"]),
              ("get", "pods", runtime["runner_namespace"], "log"), ("create", "pods", runtime["runner_namespace"], "exec"),
              ("create", "configmaps", "bookinfo"), ("delete", "pods", "monitoring"), ("get", "nodes", None)]
    for permission in denied:
        verb, resource, namespace, *subresource = permission
        command = ["kubectl", "--context", kube.context, "--request-timeout=10s", "auth", "can-i", verb, resource]
        if subresource:
            command += ["--subresource", subresource[0]]
        if namespace:
            command += ["--namespace", namespace]
        result = subprocess.run(command, text=True, capture_output=True, timeout=min(15, max(1, deadline - time.monotonic())))
        if result.returncode != 1 or result.stdout.strip() != "no":
            raise ValueError("Expected denial was not established: " + verb + " " + resource)
    return sorted((o["kind"], o["metadata"]["name"], o["metadata"]["uid"]) for o in kube.inventory(deadline))


if __name__ == "__main__":
    runtime = C["runtime_config"](C["runtime_from_env"]())
    kube = K.Kube(runtime["runner_namespace"])
    started = time.monotonic()
    before = verify(runtime, kube, started + 90)
    print("First scoped permission/API check:", datetime.now(timezone.utc).isoformat(), flush=True)
    # Each invocation executes aws eks get-token; the second check occurs beyond token lifetime.
    while time.monotonic() - started <= 910:
        time.sleep(min(30, max(0.1, 911 - (time.monotonic() - started))))
    after = verify(runtime, kube, started + 1080)
    print("Renewed scoped permission/API check:", datetime.now(timezone.utc).isoformat(), flush=True)
    print(json.dumps({"inventory_unchanged": before == after, "elapsed_seconds": time.monotonic() - started,
                      "mechanism": "fresh AWS CLI exec token per bounded kubectl invocation; same assumed STS session"}))
    if before != after:
        raise SystemExit("Generator inventory changed during access verification; reconcile concurrent activity")
