#!/usr/bin/env python3
"""Normalize dispatch input before requesting cloud credentials."""

import argparse
import ipaddress
import os
from pathlib import Path
import re
import runpy
import sys
from urllib.parse import urlsplit

C = runpy.run_path(str(Path(__file__).with_name("load-test-common.py")))


def hostname(value):
    if not isinstance(value, str) or not value or re.search(r"[\s/:@*?#\\]", value):
        raise ValueError("Target URL must contain a valid DNS hostname")
    try:
        value = value.removesuffix(".").encode("idna").decode("ascii").lower()
    except UnicodeError as error:
        raise ValueError("Invalid internationalized hostname") from error
    if len(value) > 253 or any(not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label) for label in value.split(".")):
        raise ValueError("Invalid DNS hostname")
    try:
        ipaddress.ip_address(value)
    except ValueError:
        return value
    raise ValueError("Target URL must use a DNS hostname, not an IP literal")


def target_url(value):
    if not isinstance(value, str) or not value or re.search(r"[\s\\\x00-\x1f\x7f-\x9f]", value):
        raise ValueError("Target URL is required and must not contain whitespace, control characters or backslashes")
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError as error:
        raise ValueError("Target URL has an invalid hostname or port") from error
    if parsed.scheme not in ("http", "https"):
        raise ValueError("Target URL must use HTTP or HTTPS")
    if parsed.username is not None or parsed.password is not None or "#" in value:
        raise ValueError("Target URL must not contain credentials or a fragment")
    hostname(parsed.hostname)
    if parsed.netloc.endswith(":") or port == 0:
        raise ValueError("Target URL port must be between 1 and 65535")
    if re.search(r"%(?![0-9a-fA-F]{2})", value):
        raise ValueError("Target URL contains an invalid percent escape")
    return value


def integer(value, limits, name):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]{1,5}", value):
        raise ValueError(name + " must be an unsigned integer")
    number = int(value)
    if not limits["min"] <= number <= limits["max"]:
        raise ValueError(name + " is outside the configured range")
    return number


def normalize(event, runtime, policy, env=None, head=None):
    C["runtime_config"](runtime)
    result = C["source_identity"](event, runtime, env, head)
    inputs = event.get("inputs", {})
    url = target_url(inputs.get("target_url", ""))
    scenario = inputs.get("test_scenario", "bookinfo.js")
    C["scenario_script"](scenario)
    for name, limits in policy["inputs"].items():
        result[name] = integer(inputs.get(name, str(limits["default"])), limits, name)
    result.update(target_url=url, test_scenario=scenario, validation_status="accepted", validation_error=None)
    result["job_timeout_minutes"] = (result["duration_seconds"] + 59) // 60 + 25
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("event", "output"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--policy", help="Required when validating workload inputs")
    parser.add_argument("--source-only", action="store_true", help="Validate deployment and dispatch source without load inputs")
    args = parser.parse_args()
    if not args.source_only and not args.policy:
        parser.error("--policy is required unless --source-only is selected")
    result = dict.fromkeys(("run_id", "repository", "workflow_sha", "workload_sha",
                            "target_url", "test_scenario", "total_vus", "duration_seconds", "runners", "job_timeout_minutes"))
    try:
        event, runtime = C["read"](args.event), C["runtime_from_env"]()
        if args.source_only:
            C["runtime_config"](runtime)
            result = C["source_identity"](event, runtime)
            result.update(validation_status="accepted", validation_error=None)
        else:
            result = normalize(event, runtime, C["read"](args.policy))
    except (ValueError, KeyError, OSError) as error:
        result.update(validation_status="rejected", validation_error=str(error))
        C["write"](args.output, result)
        print("Request rejected: " + str(error), file=sys.stderr)
        return 1
    C["write"](args.output, result)
    if os.environ.get("GITHUB_OUTPUT") and "job_timeout_minutes" in result:
        with open(os.environ["GITHUB_OUTPUT"], "a") as stream:
            stream.write(f"job_timeout_minutes={result['job_timeout_minutes']}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
