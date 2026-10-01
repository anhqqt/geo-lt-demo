# 0003: Use k6 Operator for distributed load generation

- [Context](#context)
- [Alternatives](#alternatives)
- [Decision](#decision)
- [Consequences](#consequences)

**Status:** Accepted

## Context

With [EKS selected](0002-eks-execution-platform.md), the project needs a generator that can share a requested load across runners, use dedicated generator hosts and report useful HTTP results. Developers should maintain the workload in Git and enter bounded inputs without writing Kubernetes resources for each test.

The target and its real dependencies are ready before a run. Shared Prometheus/Grafana must show live metrics and retain results after generator cleanup. The demo returns a GitHub Actions Summary, with a Grafana link for manual assessment when a measurement interval is available.

The choice includes the work needed to distribute load, collect results and clean up. Generator features alone do not establish a complete self-service workflow.

## Alternatives

- [Load generators](#load-generators)
- [Grafana dashboard](#grafana-dashboard)

### Load generators

| Option | Reasons to consider it | Integration cost |
|---|---|---|
| **k6 Operator, selected** | JavaScript HTTP checks, distributed execution through TestRun, runner placement/identity settings and native-histogram remote write | A controller and its permissions to maintain; experimental remote-write output; thresholds evaluated separately by runners |
| **Locust with master/worker Jobs** | Python workloads, centralized statistics and a programmable verdict; first-party OpenTelemetry support | Owned Job manifests, telemetry configuration, dashboard wiring and result capture before cleanup |
| **JMeter with controller/remote-engine Jobs** | Visual test authoring, centralized samples and HTML reports | Explicit division of total VUs, JVM/RMI setup, engine shutdown and a separately maintained Prometheus extension |

k6 Operator was selected because its JavaScript checks fit the workload and TestRun exposes the distribution, scheduling and identity controls needed on EKS. The direct Prometheus path and available dashboards also fit the shared monitoring design. Grafana's [published release policy](https://github.com/grafana/k6-operator/blob/main/docs/releases.md) and recorded fixes support the maintenance rationale, without proving this project's integration.

Locust's [central statistics](https://docs.locust.io/en/stable/running-distributed.html) remain an advantage. Its [OpenTelemetry implementation](https://raw.githubusercontent.com/locustio/locust/2.46.6/locust/opentelemetry.py) can export request histograms through OTLP. The compared design uses owned Jobs because the reviewed [Locust Operator schema](https://github.com/locustio/k8s-operator/blob/master/charts/locust-operator/crds/locusttest.yaml) lacks the required node-selection, toleration and ServiceAccount controls. Receiver configuration and dashboards would still need integration.

JMeter's reporting could support a fuller report package. Each remote engine [runs the complete test plan](https://jmeter.apache.org/usermanual/remote-test.html), so this project's total-VU input would need explicit allocation across engines. Its built-in live backends and external Prometheus integration add another configuration choice.

### Grafana dashboard

Dashboard [18030, revision 8](https://grafana.com/api/dashboards/18030/revisions/8/download) was selected for its native-histogram latency queries and the standard k6 remote-write schema. Merging runner histograms before calculating percentiles fits distributed results; averaging precomputed runner percentiles does not produce a combined percentile.

The recorded dashboard comparison found:

- Dashboard 19665 and reviewed classic-statistic variants averaged precomputed percentiles. Reviewed 20108 and 22746 copies did not improve 18030's queries.
- Other Prometheus variants had narrower request coverage, incompatible names, missing run filters or aggregation problems.
- InfluxDB, ClickHouse, k6 Cloud and StatsD-exporter dashboards required a different data path.

These findings describe the versions reviewed for this decision. The accepted demo uses unmodified upstream revision 8, with its display limitations documented. The [metrics section below](#metrics-and-dashboard-queries) explains how those limits affect interpretation.

## Decision

- [Workload and load distribution](#workload-and-load-distribution)
- [Thresholds and execution status](#thresholds-and-execution-status)
- [Metrics and dashboard queries](#metrics-and-dashboard-queries)
- [Reporting and cleanup](#reporting-and-cleanup)
- [Ownership and permissions](#ownership-and-permissions)

### Workload and load distribution

Use a versioned k6 JavaScript workload and one TestRun per attempt. The workflow and workload use the same resolved default-branch commit. Automation validates total VUs, duration, runner count, complete target URL and selected scenario file, then creates the script ConfigMap and TestRun. The initial scenario is `bookinfo.js`; the dropdown filename resolves to `load-tests/<test_scenario>` in that dispatch commit.

The k6 Operator uses execution segments to distribute the requested total VUs across runners. `parallelism` controls runner count; increasing it must not multiply the requested concurrency. The [input table](../specification.md#request-and-inputs) owns defaults and ranges. These are configuration ceilings; [short load samples](../validation.md#current-capacity-samples) establish no sustained or maximum capacity. [TestRun controls](https://grafana.com/docs/k6/latest/set-up/set-up-distributed-k6/usage/configure-testrun-crd/) provide the runner interface.

Each VU in `bookinfo.js` repeats one GET to the unchanged `TARGET_URL` and one `status === 200` check, then starts the next iteration without deliberate sleep. Throughput is measured from that workload; it is not a requested fixed arrival rate. Both internal Service DNS and public HTTPS target the prepared service.

Non-200 responses and transport failures count as unsuccessful requests. Configure the workload's HTTP outcome metrics to match that strict status rule. Response-content assertions are deferred: HTTP 200 can hide a failed dependency or incomplete page, so these measurements do not establish business correctness.

### Thresholds and execution status

Keep the following native k6 thresholds fixed in the workload in Git. The self-service UI offers no threshold override.

| Per-runner diagnostic | Accepted threshold |
|---|---|
| HTTP request duration | p95 below 1 second |
| Strict HTTP 200 success | At least 99%; failures, including transport failures, at most 1% |

These are demo diagnostics, not production SLOs or assignment-prescribed targets. Request duration covers sending, waiting and receiving, excluding initial DNS lookup and connection establishment. Each k6 process evaluates [only its own observations](https://grafana.com/docs/k6/latest/testing-guides/running-large-tests/#distributed-execution).

Do not enable `abortOnFail`. Threshold breaches alone leave load and metrics running for the requested duration. At completion, a breached threshold makes that runner fail; the workflow must still allow other runners to finish. Cancellation, timeout and execution faults have separate stop behavior.

GitHub Actions observes all expected runner Job outcomes through EKS. A TestRun reaching `finished` is insufficient because the reviewed k6 Operator completion logic also counts failed Jobs. The workflow uses these rules:

- Every expected runner succeeds, the required Summary is published and cleanup is verified: green.
- Any runner fails, an expected terminal outcome is missing, reporting fails or cleanup is failed/unverified: red, with the affected outcomes visible separately.
- Cancellation or timeout: preserve that outcome, stop traffic and attempt cleanup using the available results.

Execution status, performance assessment and cleanup status remain distinct. A green workflow does not certify complete telemetry or combined performance. The demo adds no Prometheus-query step or custom evaluator to calculate a global verdict.

### Metrics and dashboard queries

Send built-in k6 Prometheus remote write directly to internal Prometheus, with native histograms for latency. Grafana uses the chart-provisioned datasource. This avoids another collector, sidecar or telemetry gateway. The [remote-write output](https://grafana.com/docs/k6/latest/results-output/real-time/prometheus-remote-write/) is experimental. The [validation record](../validation.md#current-workflow-verification) covers its tested use with this stack.

Every runner must have the same `run_id` and matching `testid` dashboard alias, plus a distinct `instance_id`. Pass the run tags through TestRun arguments: the recorded smoke showed that k6 Operator CLI tags replaced tags supplied only in the script. Separate runner series prevent writers from colliding and allow metrics to be combined deliberately.

The chart provisions unmodified dashboard 18030, revision 8. That configuration is deployed, with a no-change bootstrap plan and basic Viewer checks for live data, run filtering and retained results. Custom query corrections and exhaustive numerical panel acceptance are outside the accepted demo scope.

Interpret the upstream panels with these limits:

- VUs are averaged across runner series; that display does not establish total configured concurrency. Check distinct runner series when assessing distribution.
- Check-rate rounding can hide small differences. An upstream success or failure panel alone does not certify exact whole-run counts or complete telemetry.
- Merged native histograms support distributed latency views, but a rolling percentile is not a whole-run percentile. Waiting time also covers only part of request duration.
- Missing data stays unknown. The observed failure stat showed no data after cleanup; that does not mean zero failures or PASS.

No recording-rule layer or metric service is added. Automated whole-run evaluation and final-count reconciliation remain future work.

### Reporting and cleanup

At the end of a run, publish a concise GitHub Actions Summary and a Grafana link filtered to the run ID and interval. Retain run configuration, source SHAs, execution status, known data gaps and separate cleanup status. A detailed per-runner report or exit-code table is not required.

The workflow controls reporting and removal. Omit TestRun `spec.cleanup` so the k6 Operator does not remove resources before their outcomes are observed:

1. Observe all expected runner Job outcomes and prepare the available report and Grafana link before removal.
2. Delete the run's TestRun and associated generated resources.
3. Delete the script ConfigMap separately; referencing it does not make it a TestRun child.
4. Verify that all tracked objects are gone, then publish one Summary with separate execution and cleanup status.

Attempt cleanup even if report preparation fails, and keep publication failures visible. Cancellation or timeout must stop load, retain available results and attempt removal while preserving the original outcome. A lost GitHub runner can leave resources behind; recovery must identify those leftovers and their cost exposure. The [run lifecycle](../architecture.md#end-the-run) owns deadlines, retry behavior and recovery limits.

Cleanup preserves the generator namespace and controls, other runs, Bookinfo and its dependencies, shared monitoring/data and the foundation. Metrics remain available within Prometheus retention and storage limits; Summary retention follows repository settings. Final foundation teardown ends access to in-cluster monitoring.

The demo provides no downloadable result artifacts and does not retain or forward k6 logs or native stdout summaries. Detailed runner logs disappear with cleanup. GitHub execution logs are separate and do not replace that diagnostic history.

### Ownership and permissions

Bootstrap installs k6 Operator as a persistent platform component. Its manager runs on `main`; initializer, starter and runner Pods use `load-test`, with explicit placement and resource settings. The [EKS decision](0002-eks-execution-platform.md#bounded-capacity) owns compute bounds and the capacity caveats.

Workflow, controller and runner identities are separate. The controller retains chart cluster RBAC; watching `k6-runners` narrows reconciliation, not its authorization. Runner Pods use the namespace's default ServiceAccount with no extra workload API grants and token mounting disabled.

Namespace RBAC cannot enforce ownership between concurrent runs or validate arbitrary TestRun/Pod fields. Trusted templates and object tracking must enforce the run boundary. The [access section](../architecture.md#5-access-and-operating-limits) records those limits and the deferred admission/NetworkPolicy controls.

## Consequences

- [Benefits and costs](#benefits-and-costs)
- [Evidence and limits](#evidence-and-remaining-work)

### Benefits and costs

The k6 Operator supplies a documented Kubernetes interface for distributed k6 execution, while JavaScript keeps the workload in the repository. Direct remote write reuses shared monitoring, and native histograms support combined latency views without averaging runner percentiles.

The platform must maintain the controller, review its permissions and validate version compatibility. Workflow code still owns input checks, execution-status mapping, reporting and cleanup. Locust's centralized statistics remain a useful alternative when combined automatic evaluation is a stronger requirement.

Manual performance assessment keeps the demo's evaluator scope small, but leaves interpretation and known data gaps to the developer. Limited log retention makes later diagnosis harder. The [next-week priorities](../../WRITEUP.md#with-another-week) include automated whole-run evaluation and retained k6 logs through Loki or an existing logging system.

<a id="evidence-and-remaining-work"></a>

### Evidence and limits

The initial arithmetic-only TestRun split two total VUs across two runners, completed and removed its owned resources. A Prometheus-readiness probe established distinct runner histograms, common run tags, Viewer queries and Prometheus/Grafana Pod-recreation persistence, followed by probe cleanup. Impersonated permission checks accompanied these probes; they did not establish Bookinfo performance or authenticate from GitHub.

Later published workflows demonstrated genuine OIDC access and token renewal, public/internal Bookinfo load, strict HTTP-200 failures, native latency failures without early abort, one Summary and verified cleanup. Metrics retained distinct runner identities after removal. The [validation record](../validation.md#current-workflow-verification) keeps earlier threshold failures and deployment interference separate from passing samples and their resource baselines.

Upstream dashboard revision 8 is deployed. A Viewer observed live metrics and reopened the fixed-time Summary link after cleanup. These checks establish basic access, filtering and retention; they do not certify every panel, exact whole-run counts or complete telemetry.

Active cancellation, concurrent-run preservation and original-UID recovery of force-cancel leftovers have AWS evidence. Timeout, partial creation and other injected faults have controlled local coverage where recorded, without equivalent AWS fault claims. Publication, independent Git-clone checks, hosted timer verification and four videos are complete and accepted. Additional injected AWS faults are outside the final demo scope.
