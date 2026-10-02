"""Shared file, configuration and source contracts for the run commands."""

import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD_UID = "a3b2aaa8-bb66-4008-a1d8-16c49afedbf0"
RUNTIME_VARIABLES = {
    "aws_account_id": "AWS_ACCOUNT_ID",
    "aws_region": "AWS_REGION",
    "cluster_name": "AWS_CLUSTER_NAME",
    "workflow_role_arn": "AWS_ROLE_ARN",
    "runner_namespace": "LOAD_TEST_NAMESPACE",
    "runner_service_account": "LOAD_TEST_SERVICE_ACCOUNT",
    "remote_write_url": "PROMETHEUS_REMOTE_WRITE_URL",
    "grafana_url": "GRAFANA_URL",
    "repository": "LOAD_TEST_REPOSITORY",
    "repository_id": "LOAD_TEST_REPOSITORY_ID",
    "repository_owner_id": "LOAD_TEST_REPOSITORY_OWNER_ID",
    "default_branch": "LOAD_TEST_DEFAULT_BRANCH",
}
RUNTIME_KEYS = set(RUNTIME_VARIABLES) | {"dashboard_uid"}


def module(name):
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(name + ".py"))
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


def scenario_script(name):
    if not isinstance(name, str) or len(name) > 67 or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*\.js", name):
        raise ValueError("Test scenario must be a .js filename with a lowercase alphanumeric/hyphen stem, up to 64 characters")
    path = ROOT / "load-tests" / name
    if path.is_symlink() or not path.is_file():
        raise ValueError("Test scenario must name an existing regular file in load-tests/")
    return path


def read(path, default=None):
    path = Path(path)
    if not path.exists() and default is not None:
        return default.copy()
    return json.loads(path.read_text())


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def dns_label(value, service=False):
    first = "[a-z]" if service else "[a-z0-9]"
    if not isinstance(value, str) or not re.fullmatch(first + r"(?:[a-z0-9-]{0,61}[a-z0-9])?", value):
        raise ValueError("Invalid Service or namespace DNS label")
    return value


def runtime_from_env(env=None):
    env = os.environ if env is None else env
    value = {key: env.get(name, "") for key, name in RUNTIME_VARIABLES.items()}
    return {**value, "dashboard_uid": DASHBOARD_UID}


def runtime_config(value):
    if set(value) != RUNTIME_KEYS:
        raise ValueError("Unexpected runtime configuration fields")
    missing = [name for key, name in RUNTIME_VARIABLES.items()
               if not isinstance(value[key], str) or not value[key].strip()]
    if missing:
        raise ValueError("Set required repository variables: " + ", ".join(missing))
    if not re.fullmatch(r"[0-9]{12}", value["aws_account_id"]):
        raise ValueError("Invalid AWS account")
    if not re.fullmatch(r"[a-z]{2}(?:-gov)?-[a-z]+-[0-9]", value["aws_region"]):
        raise ValueError("Invalid AWS region")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,99}", value["cluster_name"]):
        raise ValueError("Invalid cluster name")
    if not re.fullmatch(r"arn:aws:iam::" + value["aws_account_id"] + r":role/[A-Za-z0-9+=,.@_/-]+", value["workflow_role_arn"]):
        raise ValueError("Workflow role does not belong to the configured account")
    for key in ("runner_namespace", "runner_service_account"):
        dns_label(value[key])
    paths = {"remote_write_url": ("http", "/api/v1/write"), "grafana_url": ("https", "")}
    for key, (scheme, path) in paths.items():
        uri = urlsplit(value[key])
        if (uri.scheme != scheme or not uri.hostname or uri.username or uri.password
                or uri.query or uri.fragment or uri.path.rstrip("/") != path):
            raise ValueError("Invalid runtime URL: " + key)
        if scheme == "http" and not uri.hostname.endswith(".svc.cluster.local"):
            raise ValueError("Internal endpoint must use cluster Service DNS")
    if value["dashboard_uid"] != DASHBOARD_UID:
        raise ValueError("Unexpected dashboard UID")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", value["repository"]):
        raise ValueError("Invalid repository")
    for key in ("repository_id", "repository_owner_id"):
        if not re.fullmatch(r"[1-9][0-9]*", value[key]):
            raise ValueError("Invalid repository identity")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_./-]*", value["default_branch"]):
        raise ValueError("Invalid default branch")
    return value


def source_identity(event, runtime, env=None, head=None):
    env = os.environ if env is None else env
    repo = event.get("repository", {})
    branch = repo.get("default_branch")
    ref = "refs/heads/" + runtime["default_branch"]
    expected = {"GITHUB_EVENT_NAME": "workflow_dispatch", "GITHUB_REPOSITORY": runtime["repository"],
                "GITHUB_REPOSITORY_ID": runtime["repository_id"],
                "GITHUB_REPOSITORY_OWNER_ID": runtime["repository_owner_id"], "GITHUB_REF": ref}
    if any(env.get(k) != v for k, v in expected.items()):
        raise ValueError("Dispatch event, repository identity or source branch rejected")
    if (branch != runtime["default_branch"] or str(repo.get("id")) != runtime["repository_id"]
            or repo.get("full_name") != runtime["repository"]
            or str(repo.get("owner", {}).get("id")) != runtime["repository_owner_id"]):
        raise ValueError("Event repository metadata differs from runtime configuration")
    workflow = env.get("GITHUB_WORKFLOW_REF", "")
    allowed = {runtime["repository"] + "/.github/workflows/" + name + "@" + ref
               for name in ("load-test.yml", "verify-load-test-access.yml")}
    if workflow not in allowed:
        raise ValueError("Workflow source rejected")
    sha = env.get("GITHUB_SHA", "")
    if head is None:
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or sha != env.get("GITHUB_WORKFLOW_SHA") or sha != head:
        raise ValueError("Workflow, dispatch and checked-out workload commits must match")
    run = env.get("GITHUB_RUN_ID", "") + "-" + env.get("GITHUB_RUN_ATTEMPT", "")
    if not re.fullmatch(r"[1-9][0-9]{0,19}-[1-9][0-9]{0,9}", run):
        raise ValueError("Invalid GitHub run identity")
    return {"run_id": run, "repository": runtime["repository"], "workflow_sha": sha, "workload_sha": head}
