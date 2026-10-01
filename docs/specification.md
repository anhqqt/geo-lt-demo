# Specification

- [1. Purpose and scope](#1-purpose-and-scope)
- [2. Assignment requirements](#2-assignment-requirements)
- [3. Run behavior](#3-run-behavior)
- [4. Guardrails and lifecycle](#4-guardrails-and-lifecycle)
- [5. Acceptance and completion](#5-acceptance-and-completion)

Find a criterion: [SCOPE overview](#scope-overview) or [SAFE overview](#guardrail-overview). These tables summarize the criteria; their links lead to the full requirements.

This specification defines the final demonstrated scope and acceptance evidence for self-service load testing. The assignment requires a working prototype and justified guardrails. AWS, EKS, Bookinfo and temporary k6 resources are this project's choices.

> Status: complete and accepted. The final demo includes the published implementation, independent Git-clone checks against retained Dev, hosted timer verification and four videos. Genuine workflow access, bounded Bookinfo load, upstream dashboard/Viewer checks and run cleanup have passed within the evidence scopes below. Unrun exercises are excluded from completion and are not reported as passes.

SRC-01 is the two-page brief, *Sr. DevOps Engineer (Sep 2026) - Take-home Assignment*. Page references below refer to that brief. SRC-02 covers the project's accepted scope and decisions. REQ identifiers describe assignment obligations; SCOPE, SAFE and EVID define how this demo meets and demonstrates them.

The [architecture](architecture.md) explains the design, [ADRs](decisions/README.md) record alternatives and trade-offs, and [setup](setup.md) owns deployment procedures. This document defines the contract; the [validation record](validation.md#acceptance-coverage) identifies completed checks and their limits.

## 1. Purpose and scope

- [Scope overview](#scope-overview)
- [Demo boundary](#demo-boundary)
- [Assumptions and prerequisites](#assumptions-and-prerequisites)
- [Exclusions](#exclusions)

### Scope overview

| ID | Meaning | Details |
|---|---|---|
| <a id="scope-01"></a>SCOPE-01 | Demonstrate the complete AWS test flow through verified run cleanup. | [Demo boundary](#demo-boundary); [Required evidence](#required-evidence) |
| <a id="scope-02"></a>SCOPE-02 | Let developers request bounded runs through GitHub Actions using a versioned workload. | [Demo boundary](#demo-boundary); [Request and inputs](#request-and-inputs) |
| <a id="scope-03"></a>SCOPE-03 | Keep Bookinfo as the demo; document scenario registration and retain IaC reuse. | [Exclusions](#exclusions); [Foundation lifecycle](#foundation-lifecycle) |
| <a id="scope-04"></a>SCOPE-04 | Run the Bookinfo workload and return execution status, metrics and cleanup status. | [Workload](#workload); [Results](#results-and-execution-status); [Metrics and retention](#metrics-and-retention) |
| <a id="scope-05"></a>SCOPE-05 | Test prepared Bookinfo and real dependencies, with separate application and generator hosts. | [Demo boundary](#demo-boundary); [Workload](#workload) |
| <a id="scope-06"></a>SCOPE-06 | Use Terragrunt and Terraform for foundation setup and shared services. | [Demo boundary](#demo-boundary); [Foundation lifecycle](#foundation-lifecycle) |

### Demo boundary

**[SCOPE-01](#scope-01), [SCOPE-06](#scope-06):** Demonstrate the deployed AWS foundation, ready services, a bounded load run, visible results and verified run cleanup. Foundation creation has recorded evidence; final reproduction uses a Git clone against the retained Dev deployment. Repeating blank-account bootstrap is outside this demo.

The demo uses Singapore (`ap-southeast-1`); other environments and regions are layout examples.

**[SCOPE-02](#scope-02), [SCOPE-05](#scope-05):** Developers use GitHub Actions with their Git identity, without a personal kubeconfig or infrastructure ticket for each run. The platform maintainer prepares Bookinfo, real dependencies and shared monitoring beforehand. Terraform modules and Terragrunt manage the foundation separately from ordinary runs.

| Resource boundary | Owner | Required lifetime |
|---|---|---|
| Bookinfo, dependencies/data, EKS/node groups, network, ALB/DNS/TLS and monitoring | Platform maintainer | Across runs |
| Generator namespace, ServiceAccounts and RBAC | Foundation bootstrap | Across runs |
| TestRun, script ConfigMap, generated Jobs, Pods and helper Services | Run workflow | One attempt, followed by verified removal |
| Summary and monitoring results | GitHub and shared monitoring | Accessible after generator cleanup, within their retention limits |

The application and generators use separate hosts. Runs share one persistent generator namespace and trusted automation, without isolation between untrusted users.

Shared deployments and other traffic can affect measurements. Results do not prove production capacity or isolate a candidate regression.

### Assumptions and prerequisites

The identifiers retain the original assumptions and their source. Some record explicit requirements or selected scope rather than uncertain facts.

| ID | Basis | Requirement or prerequisite |
|---|---|---|
| ASSUME-01 | Assignment | One representative microservice is sufficient; choose AWS or GCP. |
| ASSUME-02 | Selected scope | Demonstrate the AWS execution path. Local load execution is outside scope. |
| ASSUME-03 | Authorization | Cloud spending and the selected load target require authorization. Document initial access; ordinary runs then need no setup ticket. |
| ASSUME-04 | Identity | Developers use GitHub identity; automation uses a separate OIDC role. The maintainer supplies independent AWS/EKS credentials with verified identity, permissions and lifetime. No new IAM user or SSO deployment is required. |
| ASSUME-05 | Prepared target | The maintainer prepares the candidate, dependencies, resources and data before each run. No stable or reserved Dev measurement window is assumed. |
| ASSUME-06 | Public access | Control a domain/subdomain. Create the child Route 53 zone, complete and verify parent NS delegation, then request the regional ACM certificate. |

[Setup prerequisites](setup.md#prerequisites) describe credential selection and domain configuration. Existing or temporary credentials must remain valid for the operation. An assumed prerequisite must be verified before relying on it.

### Exclusions

**[SCOPE-03](#scope-03):** The demo targets Bookinfo. A short script-registration guide supports other prepared services. Reusable IaC remains required under REQ-05.

Deploying or demonstrating a second target, general service onboarding, and schema, seed or reset procedures for stateful workloads remain outside scope.

The prototype excludes:

- A service catalog, generic dependency provisioning and a polished portal.
- Multi-cloud deployment, production benchmarking and sample-service optimization.
- Response-content assertions, automated whole-run performance verdicts and historical cross-run analytics.
- Downloadable result artifacts and k6 log retention after cleanup.

A bounded per-run dashboard is included. Admission policies, generator NetworkPolicy and private-access improvements are outside the final demo; [With another week](../WRITEUP.md#with-another-week) records optional priorities.

The final scope also excludes additional injected AWS fault scenarios, maximum or sustained capacity certification, node/AZ and state/backend recovery exercises, and alternate-account checks.

Fresh grouped or repeated blank-account bootstrap, integration access removal, full-pillar destruction and foundation decommission are outside completion. These unrun exercises limit the evidence; they do not create completion tasks. Module release automation, separate recipient-account playback and ZIP reproduction are outside the selected Git-repository delivery route.

## 2. Assignment requirements

All nine requirements come from SRC-01. The brief leaves cloud, environment approach, generator, IaC, developer interface, dependencies and controls for the project to choose.

| ID | Required outcome or deliverable | Brief source |
|---|---|---|
| REQ-01 | On-demand testing without setup/teardown tickets; a clear developer procedure and justified cost, isolation, default, teardown and security controls | p. 1, Goal |
| REQ-02 | AWS or GCP, with an explained ephemeral-environment approach | p. 1, Scope |
| REQ-03 | Defined generator, IaC, CI/CD, dependency strategy, guardrails and developer results | pp. 1 to 2, Scope |
| REQ-04 | A working end-to-end prototype for at least one representative microservice; a trivial sample is acceptable | p. 2, Deliverables |
| REQ-05 | Cloud IaC modules structured for real reuse and a CI/CD pipeline; no prescribed module count | p. 2, Deliverables |
| REQ-06 | One repository, delivered by GitHub link or ZIP, with README instructions for local or cloud execution; both paths are not required | p. 2, Deliverables |
| REQ-07 | Root `AI-USAGE.md`: tools, representative prompts, agentic workflow/configuration and validation of AI output before use | pp. 1 to 2 |
| REQ-08 | A demo video of the working product; the brief specifies no duration or hosting service | p. 2, Deliverables |
| REQ-09 | Root `WRITEUP.md`, within the stated 2 to 3-page maximum: assumed context, alternatives, choices/reasons, trade-offs and another-week work | p. 2, Deliverables |

The writeup must cover environment provisioning, generator, IaC layout and developer interface alternatives, plus cost, complexity, blast radius, developer experience and security. It must explain both developer experience and guardrails from REQ-01. ADRs support that writeup; they do not replace its self-contained content or page limit.

## 3. Run behavior

- [Request and inputs](#request-and-inputs)
- [Workload](#workload)
- [Results and execution status](#results-and-execution-status)
- [Metrics and retention](#metrics-and-retention)

### Request and inputs

[SCOPE-02](#scope-02) and **[SAFE-01](#safe-01)** require source and input checks before AWS credentials, generator creation or traffic. Developers own the workload in Git; automation owns the native Kubernetes manifests.

- Use the same resolved default-branch dispatch commit for workflow and workload. Record both SHAs and keep them fixed throughout the run.
- Offer no separate workload ref, release/tag/feature-branch/PR source or user-supplied Kubernetes manifest.
- Authorized team members may inspect results and cancel group runs. The workflow uses its own execution identity.

Twelve Repository Variables supply deployment settings and repository identity. Validate every required value before AWS credentials. They are stored outside Git, so a rerun may use settings changed after the original commit; equal source SHAs do not freeze those settings.

| Input | Default | Inclusive integer range |
|---|---:|---:|
| Total concurrent VUs | 20 | 20 to 1,000 |
| Load duration | 60 seconds | 60 to 18,000 seconds |
| Runner count | 2 | 2 to 10 |

**[SAFE-02](#safe-02):** Runners share the requested total VUs. Increasing runner count must not multiply that load. Bounds are configuration limits; the short samples in [validation](validation.md#current-capacity-samples) establish no sustained or maximum capacity.

Use one `target_url` input for public or internal destinations. The default is `http://productpage.bookinfo.svc.cluster.local/productpage`.

Supply the complete `target_url`, including its path and any query. URL validation must:

- Accept HTTP or HTTPS with a DNS hostname and optional valid port.
- Preserve the supplied URL exactly, without adding a path.
- Reject malformed URLs or percent escapes, credentials, fragments, raw whitespace/control characters, backslashes, invalid ports and IP literals.
- Explain rejected inputs before AWS credentials, provisioning or traffic.

URL validation does not classify public/private DNS resolution or enforce destination authorization.

Select `test_scenario` from the workflow dropdown; its initial and default option is `bookinfo.js`. Use a stem of at most 64 characters, made of lowercase letters and digits with single hyphens allowed between groups, followed by `.js`.

Resolve the selection directly to a regular, non-symlink file at `load-tests/<test_scenario>` in the same checked-out dispatch commit. No separate ref, arbitrary path or mapping variable is accepted. Validate the file before AWS credentials, then preserve the selected script unchanged through manifest rendering.

Register another scenario in one commit: add its self-contained JavaScript file under `load-tests/` and its filename, including `.js`, to the workflow dropdown. Keep the existing `TARGET_URL`, `TOTAL_VUS` and `DURATION_SECONDS` contract, distributed `constant-vus` execution, thresholds and runtime controls.

Multi-file imports and data-file packaging are outside scope. Requesters must have permission to test the destination and its dependencies; syntax checks do not enforce that authorization.

### Workload

**[SCOPE-04](#scope-04):** Each VU in `bookinfo.js` sends a GET to the complete `TARGET_URL`, checks `status === 200`, and starts the next iteration without deliberate sleep. This is constant concurrency; achieved throughput depends on response time. Non-200 responses and transport failures count as unsuccessful requests.

Bookinfo supplies the real path `productpage → details` and `productpage → review → ratings`, using built-in synthetic data. Local `review` uses upstream `reviews-v2`. Each service has one replica, configured resources and no HPA; the demo adds no Istio, database, cache or queue. Details' external lookup is disabled.

Use the fixed Productpage baseline of one CPU / one GiB for both requests and limits. Keep that baseline and the native thresholds unchanged between capacity comparison runs. The architecture and chart defaults own the resource configuration.

GET-only describes the workload. Ratings retains its upstream POST route; the application is not protected by a general write prohibition. HTTP 200 can hide dependency or page-content failures. The [service/dependency ADR](decisions/0001-existing-dev-services-and-dependencies.md) owns these data assumptions and limits.

### Results and execution status

Return a concise GitHub Actions Summary and a Grafana link filtered to the attempt and measurement interval. The link adds 60 seconds before and 5 seconds after the recorded interval. The Summary must retain:

- Run ID, selected scenario, complete target URL, load configuration and both source SHAs.
- Measurement interval, overall execution status, separate cleanup status and known data gaps.

Detailed per-runner reports and exit-code tables are not required.

| Result | Meaning |
|---|---|
| Execution | Outcomes of every expected runner Job, including native threshold failures |
| Performance | Developer assessment of latency, achieved throughput and HTTP outcomes |
| Cleanup | Whether all tracked run-owned objects are verified absent |

Keep native thresholds fixed in Git, without UI overrides: **each runner's** request-duration p95 must be below 1 second and HTTP 200 success at least 99%. These are demo diagnostics, not assignment targets or production SLOs.

Threshold breaches must not abort the requested load. Allow other runners to finish after a threshold-only failure.

**[SAFE-07](#safe-07):** A green workflow requires every expected runner Job to succeed, the required Summary to be published and cleanup to be verified. Any failed runner makes execution fail.

Missing Jobs or terminal outcomes are incomplete; TestRun `finished` alone cannot establish success. Reporting or cleanup failure prevents green and must remain distinguishable from workload failure.

Preserve cancellation/timeout and available partial results. Workflow success does not establish complete telemetry or a whole-run performance PASS. The demo derives execution status from Jobs without a Prometheus-query evaluator.

### Metrics and retention

Send k6 metrics directly to internal Prometheus using native-histogram remote write, without an intermediate collector. Grafana provides live and post-run views of latency, achieved throughput and HTTP outcomes, including transport failures, within the accepted display limitations below.

- Use matching `run_id` and `testid` values across runners, with distinct runner identity.
- A combined percentile requires merged histograms, and combined HTTP outcomes require request-weighted counts/rates. Do not present averages of runner percentages or percentiles as whole-run results.
- Distinguish rolling-window views from whole-run values. Missing observations must remain visible and cannot establish zero failures or PASS.

Use unmodified upstream dashboard 18030, revision 8, with the provisioned Prometheus datasource. Its VU averaging and rounded check-rate displays are accepted limitations, explained in the [dashboard interpretation rules](decisions/0003-k6-operator-load-generator.md#metrics-and-dashboard-queries). Custom query corrections, exact totals and exhaustive numerical fixtures are outside acceptance.

Verify dashboard availability, run/time filtering, visible metrics and Viewer access both during a run and after cleanup. These basic checks and deployment reconciliation have passed within the recorded technical scope. A panel with no data remains unknown even when native runner checks pass.

Summary retention follows repository settings. Monitoring retains data within its storage/retention limits. Both must remain usable after generator cleanup.

k6 logs and native stdout summaries are not retained after cleanup; GitHub execution logs are separate.

## 4. Guardrails and lifecycle

- [Guardrail overview](#guardrail-overview)
- [Access and shared-resource protection](#access-and-shared-resource-protection)
- [Capacity and deadlines](#capacity-and-deadlines)
- [Run cleanup and recovery](#run-cleanup-and-recovery)
- [Foundation lifecycle](#foundation-lifecycle)

### Guardrail overview

| ID | Meaning | Details |
|---|---|---|
| <a id="safe-01"></a>SAFE-01 | Validate source, target syntax and inputs before creating generators or sending traffic. | [Request and inputs](#request-and-inputs) |
| <a id="safe-02"></a>SAFE-02 | Bound each run's load, resources and lifetime; runners share its total VUs. | [Request and inputs](#request-and-inputs); [Capacity and deadlines](#capacity-and-deadlines) |
| <a id="safe-03"></a>SAFE-03 | Stay within the authorized resource envelope and explain ongoing and leftover costs. | [Capacity and deadlines](#capacity-and-deadlines); [Cleanup and recovery](#run-cleanup-and-recovery) |
| <a id="safe-04"></a>SAFE-04 | Track run-owned resources and preserve other runs, shared services, controls and data. | [Demo boundary](#demo-boundary); [Access](#access-and-shared-resource-protection); [Cleanup](#run-cleanup-and-recovery) |
| <a id="safe-05"></a>SAFE-05 | Limit execution permissions and protect credentials and sensitive data. | [Access and shared-resource protection](#access-and-shared-resource-protection) |
| <a id="safe-06"></a>SAFE-06 | Clean up after success, failure, cancellation and timeout; support verified recovery. | [Cleanup and recovery](#run-cleanup-and-recovery); [Foundation lifecycle](#foundation-lifecycle) |
| <a id="safe-07"></a>SAFE-07 | Report Job-based execution and cleanup status without claiming a whole-run performance verdict. | [Results and execution status](#results-and-execution-status); [Metrics and retention](#metrics-and-retention) |

### Access and shared-resource protection

**[SAFE-04](#safe-04), [SAFE-05](#safe-05):** Bootstrap owns the persistent generator namespace and its access controls. The workflow may create and observe run objects and remove tracked leftovers. It must not modify namespaces, ServiceAccounts, RBAC, application/monitoring resources or foundation state.

Restrict GitHub OIDC trust to the configured repository/default branch and STS audience. Keep independent maintainer access for setup and recovery. Workflow, k6 Operator and runner identities are separate; [access design](architecture.md#5-access-and-operating-limits) defines their permissions and limits.

Namespace RBAC cannot enforce ownership between runs or validate arbitrary TestRun/Pod fields. Trusted templates must enforce resource bounds and placement; object tracking must protect other runs.

Generator NetworkPolicy and custom admission are outside this baseline. Do not claim network enforcement of destination authorization or confuse the k6 Operator's watch scope with its broader chart RBAC.

Grafana developers use local `Viewer` accounts over public HTTPS, managed by the maintainer with a separate administrator account. Disable anonymous access and self-registration; keep Prometheus ingestion and queries internal. Keep credentials and sensitive data out of source, results, video and retained logs.

### Capacity and deadlines

**[SAFE-02](#safe-02), [SAFE-03](#safe-03):** Enforce per-run inputs, fixed runner resources, placement and node-group bounds. The shared `load-test` group has minimum/initial size 1 and maximum 10. Autoscaler may adjust it within those bounds; later applies must not reset active capacity to the initial size.

Each runner requests 500m CPU and 512 MiB, with limits of 1 CPU and 1 GiB; the UI offers no override. The native TestRun template also pins helper images and resource settings. [Compute settings](architecture.md#compute-and-scaling) define all group bounds and instance choices.

Generator CPU-credit mode follows the account default; verify its effective value before interpreting capacity.

Parallel runs have no hard aggregate run or VU cap. The node ceiling neither guarantees ten concurrent runs nor creates a currency budget. Explain shared running costs, expected resource use and the cost of leftovers.

Cloud execution requires an authorized target, resource/load envelope, duration, cleanup owner and spend.

| Phase | Budget |
|---|---|
| Preparation and all required runners ready, including capacity waits | 15 minutes |
| Load | Requested duration `D` seconds |
| Graceful completion | 30 seconds |
| Observe outcomes, report and clean up | 5 minutes total |
| Hard job timeout | `ceil(D / 60) + 25` minutes; at most 325 minutes |

Phase deadlines must trigger stop/cleanup before the hard job limit. If required runners cannot start within 15 minutes, stop and clean up that run. A GitHub job timeout alone does not delete Kubernetes resources.

Count checkout and Python setup within the preparation budget. The workflow starts the timer before both and carries it across processes without resetting the deadline. Runner provisioning and action-image download before that step are outside the preparation budget.

Local cross-process checks and published hosted execution verified the timer handoff. An actual hosted timeout was not exercised.

### Run cleanup and recovery

**[SAFE-06](#safe-06):** Leave TestRun automatic cleanup disabled so the workflow can preserve results before removal:

1. Observe all expected runner outcomes.
2. Prepare the available report and Grafana link.
3. Delete the TestRun and generated resources, remove the separate script ConfigMap, and verify absence.
4. Record cleanup status and recovery information, then publish one Summary with the execution outcome and Grafana link.

Reporting failure must not prevent cleanup attempts. Names/UIDs and ownership records must distinguish this attempt from other runs.

Cleanup retries and manual recovery must create no new load. A deliberate workflow rerun is a new attempt. Never automatically replay a failed test.

| Scenario | Runtime behavior |
|---|---|
| Happy path | Bounded load, live metrics, Summary and post-run Grafana access; successful expected Jobs, reporting and verified cleanup |
| Invalid request | Useful rejection before generator creation or traffic |
| Provisioning, startup or execution failure | Preserve the original failure, retain available results and clean up what this attempt created |
| Threshold breach | Continue the requested load and let remaining runners finish; report execution failure and attempt cleanup |
| Cancellation or timeout | Stop traffic, preserve the outcome and available results, and attempt cleanup within phase budgets |
| Runner loss or cleanup failure | Identify owned leftovers, recovery steps and remaining cost exposure; verify manual recovery |
| Parallel runs or repeated cleanup | Creating, cancelling or recovering one run preserves others and namespace controls; retries remain safe |

Live evidence covers success, HTTP/threshold failure, active cancellation, peer preservation and original-UID recovery after forced orchestration loss. Timeout and additional failure paths have controlled local checks where recorded; equivalent injected AWS faults are outside acceptance.

Every cleanup preserves shared Dev services/data, ALB/DNS/TLS, cluster/node groups, monitoring/PVCs and retained results. It must never reset a shared database, flush a shared cache or purge a shared queue.

Document and verify recovery for lost or force-killed orchestration. The demo has no independent sweeper and promises no hard resource-deletion deadline after runner loss.

### Foundation lifecycle

[SCOPE-06](#scope-06) includes reusable foundation IaC, setup guidance and recorded AWS creation. The final Git-clone check uses existing Dev; a fresh grouped deployment and repeated blank-account bootstrap are outside acceptance. On bootstrap failure, stop progression and retain resources/state for diagnosis and retry.

Use reusable Terraform modules, preferring suitable public modules and documenting custom gaps. The [layer design](architecture.md#layers-and-state-boundaries) keeps seven separate states; [setup](setup.md#deploy-the-foundation) uses three layer applies. Protect S3 state with encryption, versioning, public access blocking and native locking.

Full-pillar destruction, k6 integration removal and final foundation teardown are outside this submission's scope and validation. The [maintainer procedure](setup.md#remove-the-foundation) preserves the removal order for a separately authorized operation. Shared infrastructure continues to incur costs. Removing a Helm release alone does not remove Terraform-managed IAM, stop all existing Pods or instantly revoke issued credentials.

## 5. Acceptance and completion

- [Required evidence](#required-evidence)
- [Decisions and accepted limits](#decisions-and-remaining-work)
- [Completion rule](#completion-rule)

### Required evidence

The [validation record](validation.md#acceptance-coverage) maps the completed checks to the final evidence groups below. Each group is accepted within its stated scope. A failed workload can pass a failure-handling check when its failure is reported and cleanup verified; its performance result remains failed. One record may cover several criteria.

Keep static validation, controlled local failures and Kubernetes impersonation checks distinct from actual cloud runs and genuine GitHub authentication.

| ID | Final evidence scope |
|---|---|
| EVID-01 | AWS bootstrap through ready services/monitoring, a completed self-service run, distributed metrics within accepted display limits, preserved shared resources and post-cleanup results |
| EVID-02 | Live HTTP/threshold failures, reported Job outcomes, available results and cleanup without threshold-driven early abort; controlled local checks supplement the recorded failure cases |
| EVID-03 | Genuine GitHub OIDC/token renewal and scoped permissions, hosted numeric/URL rejections, both target routes, separate generator hosts and total-VU distribution; additional source/input cases checked locally |
| EVID-04 | Active cancellation, parallel-run preservation, forced orchestration loss with live leftovers, original-UID recovery and repeated cleanup |
| EVID-05 | Reviewed reusable IaC, recorded AWS foundation creation and readiness, current source/plan checks, completed pipeline/results and verified run-resource removal with shared resources preserved |
| EVID-06 | Published Git repository, independent clone checks against retained Dev, hosted timer handoff, result retrieval and cleanup; four videos, README, writeup coverage/page limit, AI disclosure and human acceptance |

For EVID-01, verify the provisioned datasource/dashboard, native histogram ingestion, shared run tags and separate runner series. Check run/time filters, visible metrics, missing-data behavior and live/post-cleanup access as Viewer. The accepted upstream display limitations do not require custom query corrections or exhaustive panel arithmetic.

Verify configured monitoring volumes, replicas and placement, then reopen Summary/Grafana after generator cleanup. Native runner observations remain the source of threshold outcomes; dashboard views do not certify whole-run totals or percentiles.

EVID-01/03 must also prove authoritative parent/child DNS delegation, ACM issuance and working Bookinfo/Grafana HTTPS endpoints on the shared ALB. EVID-04 must demonstrate that these resources survive run cleanup.

For EVID-02, prove that non-200 responses and transport failures fail the status check, and a native threshold failure makes its runner Job and workflow fail after reporting/cleanup attempts. Missing outcomes cannot become green. A controlled run may cover several cases; an exhaustive deployment matrix is not required.

Retained evidence must identify:

- Criterion IDs, command/UI entry point, revision/artifact identity, environment, configuration and relevant tool versions.
- Run ID, selected scenario, complete target URL, separately recorded equal workflow/workload SHAs, total VUs and measurement interval.
- Observed outcomes/exit status, execution and cleanup status, sanitized evidence location and live/post-run result references.
- Manual performance assessment, dashboard windows, known missing data, limitations and checks not run.

Automated capture of deployed Dev versions/configuration and concurrent activity is outside the final demo. Disclose their possible effect on results. Evidence must establish the surviving resources and data, not just successful delete commands.

<a id="decisions-and-remaining-work"></a>

### Decisions and accepted limits

These DEC identifiers preserve decision traceability; they are separate from ADR numbering. All listed choices are accepted for the final demo.

| ID | Selected direction and owning reference |
|---|---|
| DEC-01 | AWS, one Dev account in Singapore; [environment/account layout](decisions/0005-terragrunt-iac-orchestration.md) |
| DEC-02 | EKS, dedicated workload groups and persistent generator namespace; [platform ADR](decisions/0002-eks-execution-platform.md) |
| DEC-03 | k6 Operator, native thresholds and manual assessment; [generator ADR](decisions/0003-k6-operator-load-generator.md) |
| DEC-04 | Terragrunt/Terraform, layers and separate states; [IaC ADR](decisions/0005-terragrunt-iac-orchestration.md) and [module composition](architecture.md#module-composition-and-shared-configuration) |
| DEC-05 | GitHub Actions, default-branch source and OIDC access; [workflow ADR](decisions/0004-github-actions-self-service-workflow.md) |
| DEC-06 | Prepared Bookinfo and real dependencies; [service/dependency ADR](decisions/0001-existing-dev-services-and-dependencies.md) |
| DEC-07 | Bounded resources and deadlines, without a currency cap; [capacity contract](#capacity-and-deadlines) |
| DEC-09 | AWS demonstration; local execution outside scope under ASSUME-02 |
| DEC-10 | Automatic run cleanup and verified manual recovery; [run lifecycle](#run-cleanup-and-recovery) |
| DEC-11 | Required deliverables under REQ-06 through REQ-09; four videos, a three-page WRITEUP render and human package acceptance are recorded in [validation](validation.md) |

The final acceptance preserves these evidence boundaries:

- **Verified technical scope:** genuine OIDC/token renewal, source/input rejection, bounded public/internal Bookinfo load, runner Job outcomes, one Summary, UID-scoped cleanup, active cancellation, parallel-run preservation and recovery. Upstream dashboard reconciliation and Viewer live/post-cleanup access also pass.
- **Capacity limits:** with two runners for 60 seconds, the fixed Productpage baseline passes the tested 20-VU public/internal and 40-VU internal points; 80 VUs fails internal latency. Short samples do not establish sustained or maximum capacity. Earlier failures retain their original configuration and outcome.
- **Submission package accepted:** publication, independent Git-clone reproduction against retained Dev, hosted timer verification, four videos and the three-page WRITEUP render have evidence. The user accepted the package and private-repository access handoff. Independent recipient-account playback, ZIP reproduction and blank-account bootstrap remain unverified.
- **Outside scope:** additional hosted faults, live integration removal, full-pillar destruction and foundation teardown. Monitoring Pod recreation has evidence; node/AZ recovery was not exercised. Bookinfo exposure recovery is user-confirmed.

[WRITEUP.md](../WRITEUP.md) and [AI-USAGE.md](../AI-USAGE.md) are included in the accepted final submission. The another-week proposals are optional improvements outside this completion scope.

### Completion rule

The final demo is complete: its deliverables, demonstrated behavior and evidence above have human acceptance. The [acceptance table](validation.md#acceptance-coverage) records that conclusion within the final scope. Preserve each observation's actual result and method; unrun or excluded exercises do not count as passed checks. Optional improvements and separate maintainer operations are not completion requirements.
