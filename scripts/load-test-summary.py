#!/usr/bin/env python3
"""Write a concise run report without an aggregate performance verdict."""

import argparse
from datetime import datetime
import html
from pathlib import Path
import runpy
from urllib.parse import urlencode

C = runpy.run_path(str(Path(__file__).with_name("load-test-common.py")))


def escape(value):
    return html.escape(str(value if value is not None else "unavailable")).replace("|", "&#124;").replace("\n", " ").replace("`", "&#96;")


def summary(request, record, outcome, runtime):
    status = outcome.get("execution_status", "rejected" if request.get("validation_status") == "rejected" else "incomplete")
    rows = {"Execution": status, "Cleanup": outcome.get("cleanup_status", "unknown"), "Run ID": request.get("run_id") or record.get("run_id"),
            "Scenario": request.get("test_scenario"), "Target": request.get("target_url"),
            "Total VUs / seconds / runners": " / ".join(escape(request.get(k)) for k in ("total_vus", "duration_seconds", "runners")),
            "Workflow commit": request.get("workflow_sha"), "Workload commit": request.get("workload_sha"),
            "Measurement start": outcome.get("measurement_start"), "Measurement end": outcome.get("measurement_end"),
            "Interval precision": outcome.get("interval_precision", "load start not observed"),
            "Reason": outcome.get("reason") or request.get("validation_error")}
    text = ["# Load test", "", "| Field | Value |", "|---|---|"]
    text.extend(f"| {key} | {escape(value)} |" for key, value in rows.items())
    start = outcome.get("measurement_start") or record.get("job_start_utc")
    end = outcome.get("measurement_end")
    if start and end and rows["Run ID"] and runtime.get("grafana_url"):
        def epoch(value):
            return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() * 1000)
        query = urlencode({"var-testid": rows["Run ID"], "from": epoch(start) - 60000, "to": epoch(end) + 5000})
        url = runtime["grafana_url"].rstrip("/") + "/d/" + runtime["dashboard_uid"] + "?" + query
        text += ["", f"[Open this run in Grafana]({url})", "", "The display adds 60 seconds before and 5 seconds after the observed interval. Sign in as a Viewer."]
    text += ["", "Runner thresholds are evaluated independently. Assess distributed performance in Grafana; a green workflow does not certify whole-run performance or complete telemetry."]
    gaps = outcome.get("known_incomplete_data", [])
    if gaps:
        text += ["", "Known data limits:", ""] + ["- " + escape(gap) for gap in gaps]
    roots = [root for root in record.get("roots", []) if root.get("uid")]
    if roots:
        text += ["", "Original recovery identities:", "", "| Kind | Name | UID |", "|---|---|---|"]
        text += ["| " + " | ".join(escape(root[key]) for key in ("kind", "name", "uid")) + " |" for root in roots]
        text += ["", "Use the original IDs with the setup guide's cleanup-only recovery command. GitHub Re-run starts new load."]
    if outcome.get("cleanup_error"):
        text += ["", "Cleanup error: " + escape(outcome["cleanup_error"])]
    return "\n".join(text) + "\n"


def render(request_path, record_path, outcome_path, output):
    text = summary(C["read"](request_path, {}), C["read"](record_path, {}), C["read"](outcome_path, {}), C["runtime_from_env"]())
    Path(output).write_text(text)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("request", "record", "outcome", "output"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    render(args.request, args.record, args.outcome, args.output)
