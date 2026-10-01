# 0004: Use GitHub Actions UI for self-service load tests

- [Context](#context)
- [Alternatives](#alternatives)
- [Decision](#decision)
- [Consequences](#consequences)

**Status:** Accepted

## Context

Developers need a browser interface to request, follow and cancel a bounded load test, then inspect its results. The workload lives in Git. Bookinfo and its real dependencies are prepared before testing; ordinary runs create only temporary k6 resources on the shared EKS foundation.

The intended team uses GitHub identities. Developers should not need personal AWS credentials or a kubeconfig for each run. Authorized team members can view results and cancel group runs. The workflow needs its own AWS/EKS identity, with access limited to running tests.

The choices cover three concerns: the developer interface, where orchestration runs, and which controls protect shared resources. Every option still needs input checks, useful results and verified cleanup, including failure and cancellation paths.

## Alternatives

- [Developer interface](#developer-interface)
- [Workflow runner location](#workflow-runner-location)
- [Permission boundary](#permission-boundary)

### Developer interface

| Option | Reasons to consider it | Cost for this demo |
|---|---|---|
| **GitHub Actions, selected** | Manual input form, Git identity, run status, logs and summaries beside the workload repository | Repository-level run permissions; explicit EKS connectivity, validation and cleanup logic |
| **Jenkins parameterized Pipeline** | Separate permissions for starting, reading, cancelling and configuring jobs; agents can reach a private cluster | Controller, plugins, SSO integration, storage/backups and ongoing patching |
| **Argo Workflows** | Kubernetes execution, reusable templates and queue/mutex/semaphore controls | Controller/server, secured UI, SSO mapping, template/DAG authoring and upgrades; storage if artifacts are retained |

GitHub Actions keeps the flow in the existing Git interface and avoids operating another workflow service. It supports the agreed team access model. Its built-in artifacts and concurrency controls are available capabilities; this demo selects Summary/Grafana results and does not impose a hard aggregate run cap.

[Manual dispatch](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow) requires repository write access. [Jenkins permissions](https://www.jenkins.io/doc/book/security/access-control/permissions/) offer finer separation between running a job and changing it. That remains a reason to reconsider Jenkins if the team later needs a narrower run-only role. GitHub hosting and the required organizational sign-in arrangement are prerequisites, not services this prototype configures.

Argo would require checks of [template restrictions](https://argo-workflows.readthedocs.io/en/latest/workflow-restrictions/) and cleanup behavior for the selected version. Its [release policy](https://argo-workflows.readthedocs.io/en/latest/releases/) maintains two minor branches and permits breaking changes in minor upgrades. Graceful [stop](https://argo-workflows.readthedocs.io/en/latest/cli/argo_stop/) runs exit handlers; [terminate](https://argo-workflows.readthedocs.io/en/latest/cli/argo_terminate/) skips them. Workflow garbage collection alone would not prove removal of the external k6 objects.

Jenkins completion hooks also need owned Kubernetes cleanup and recovery after controller or agent loss.

### Workflow runner location

| Option | Benefit | Accepted or deferred cost |
|---|---|---|
| **Standard GitHub-hosted runner, selected** | No runner host, registration, patching or recovery lifecycle to maintain | Uses an internet-reachable EKS API endpoint |
| Self-hosted runner on EC2 in the VPC | Reaches a private EKS API independently of cluster scheduling | Host and runner maintenance, outbound GitHub connectivity and registration credentials |
| Self-hosted runner Pod in EKS | Reuses cluster capacity and private connectivity | Depends on the cluster it manages; bootstrap and recovery need another connected executor |

The demo enables both EKS API endpoints. Hosted orchestration uses the public endpoint; requests from inside the cluster use the [private path](https://docs.aws.amazon.com/eks/latest/userguide/cluster-endpoint.html). AWS/EKS authorization and Kubernetes RBAC protect access. The public endpoint remains an accepted exposure.

Do not base access on an allowlist of all standard GitHub runner addresses. GitHub [advises against this](https://docs.github.com/en/actions/reference/runners/github-hosted-runners#ip-addresses) because the ranges are numerous and change. A private API with a self-hosted runner, or a hosted runner connected through a VPN, remains [future work](../../WRITEUP.md#with-another-week).

### Permission boundary

| Option | Benefit | Limit or additional work |
|---|---|---|
| **Direct access with trusted workflow checks, selected** | Uses namespace RBAC and existing automation; no extra provisioning service | Workflow mistakes can affect another run in the same namespace |
| Direct access plus admission validation | Kubernetes can reject disallowed resource fields independently of workflow checks | Policy design, compatibility, rule coverage and failure behavior to maintain |
| Separate provisioning controller or broker | Centralizes resource creation behind a narrower request interface | Another API, reconciliation loop, authorization boundary and recovery lifecycle |

The demo trusts reviewed default-branch workflows and workloads. Bootstrap owns one persistent generator namespace and its access controls. This removes the workflow's need to create namespaces or configure permissions on every run. A [namespace per run](../../WRITEUP.md#namespace-choice-one-shared-namespace) gives more options for per-run controls but adds provisioning and deletion work.

RBAC restricts API operations and namespaces. It cannot validate arbitrary TestRun/Pod fields or distinguish ownership between concurrent runs in one namespace. Trusted templates and verified object tracking carry those responsibilities. Custom admission and generator NetworkPolicy remain deferred; the demo offers no isolation guarantee between untrusted users.

## Decision

- [Request and source policy](#request-and-source-policy)
- [Workflow access](#workflow-access)
- [Run ownership and capacity](#run-ownership-and-capacity)
- [Results and execution status](#results-and-execution-status)
- [Cleanup and recovery](#cleanup-and-recovery)

### Request and source policy

Use a manual `workflow_dispatch` entry point with these source rules:

- Accept only the configured default branch, whose name is not assumed to be `main`.
- Resolve the dispatch commit once. Use that SHA for both workflow and k6 workload throughout the run, recording them as separate result fields even when equal.
- Offer no separate workload ref, release/tag selection, feature branch, pull-request source or user-supplied Kubernetes manifest.

GitHub's dispatch interface can select other branches. The workflow must enforce this project's narrower policy before provisioning or traffic, and OIDC trust must prevent disallowed refs from obtaining the run role. [Dispatch semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch) do not supply those restrictions automatically.

Validate target syntax and integer total-VU, duration and runner inputs against the [accepted defaults and ranges](../specification.md#request-and-inputs). Supply the complete `target_url`, including its path and any query.

The target URL accepts HTTP or HTTPS for either network path. The URL must have a DNS hostname and may have a valid port. Preserve the supplied URL exactly without adding a path. Reject malformed URLs or percent escapes, credentials, fragments, raw whitespace/control characters, backslashes, invalid ports and IP literals. There is no destination allowlist.

Select `test_scenario` from the workflow dropdown; its initial and default option is `bookinfo.js`. Use a stem of at most 64 characters, made of lowercase letters and digits with single hyphens allowed between groups, followed by `.js`. Resolve it directly to a regular, non-symlink file at `load-tests/<test_scenario>` in the same checked-out dispatch commit. No separate ref, arbitrary path or mapping variable is accepted.

Validate the file before AWS credentials, then preserve the selected script unchanged through manifest rendering.

Register another scenario by adding a self-contained JavaScript file under `load-tests/` and its filename, including `.js`, to the workflow dropdown in the same commit. Keep the existing `TARGET_URL`, `TOTAL_VUS` and `DURATION_SECONDS` contract, distributed `constant-vus` execution, thresholds and runtime controls. Multi-file imports and data-file packaging remain future work.

The requester must have permission to test the destination; syntax validation cannot establish that permission. k6 Pods generate traffic inside EKS. The GitHub-hosted runner only orchestrates and does not need to resolve internal Service DNS.

### Workflow access

The platform maintainer deploys bootstrap using independent AWS/EKS access. Bootstrap consumes cluster references and the shared GitHub OIDC provider, then prepares the run role, EKS access entry and namespace permissions before any test. The workflow has no foundation-state ownership.

The job uses this access chain:

1. **GitHub OIDC to AWS:** assume the run role with a subject matching the configured repository and default branch, and `sts.amazonaws.com` as audience. Verify the repository's actual subject format through [setup](../setup.md#account-and-project-settings); do not copy another repository's trust value.
2. **AWS identity to EKS:** use cluster-scoped `eks:DescribeCluster` and `aws eks update-kubeconfig`. A persistent `STANDARD` access entry maps the permanent IAM role ARN to a dedicated Kubernetes group.
3. **Kubernetes authorization:** a namespace RoleBinding grants that group the operations needed to create TestRuns and script ConfigMaps, observe Jobs/Pods/Services and delete tracked run leftovers.

[OIDC](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws) avoids storing long-lived AWS keys in GitHub. The role allows sessions up to six hours. The job requests that duration for execution, reporting and cleanup. AWS CLI obtains fresh EKS authentication tokens while the AWS session remains valid; token renewal does not extend it.

Do not attach broader EKS access policies alongside the namespace group mapping. Workflow permissions exclude changing namespaces, ServiceAccounts or RBAC, and modifying Bookinfo or monitoring. The configured subject must name the actual default branch; syntax validation does not discover it. Default-branch code and its review process remain part of the trust boundary.

Network reachability, temporary AWS credentials and Kubernetes authorization require separate checks. A reachable API alone does not establish workflow access.

k6 Operator uses its own Kubernetes ServiceAccount to create helper and runner resources. It needs no AWS role for those operations. Run Pods use the generator namespace's default ServiceAccount, without extra API grants or token mounting. The [controller identity rules](../architecture.md#controller-and-runner-identities) also distinguish the controller's watch scope from its broader chart authorization.

### Run ownership and capacity

Use `runId = <GITHUB_RUN_ID>-<GITHUB_RUN_ATTEMPT>` within the demo repository. Reuse the attempt ID in resource names, the `run_id` metric tag, Summary and Grafana. Track object names and UIDs as well; matching labels alone do not prove ownership.

A deliberate workflow rerun starts new load with a new attempt ID. Cleanup retries and manual recovery retain the original identity and create no new load. Failed tests are not automatically replayed.

Each attempt owns its TestRun, script ConfigMap and generated Jobs, Pods and helper Services. Bootstrap retains the namespace and controls. The existing application, real dependencies, shared data and monitoring remain outside run ownership.

Multiple runs may execute concurrently. `parallelism` means runners within one run, sharing its requested total VUs. Per-run bounds, fixed runner resources and placement combine with the shared ten-node generator ceiling; there is no hard aggregate run or VU cap. The [compute limits](../architecture.md#compute-and-scaling) do not establish available load capacity or a currency budget.

All required runners must become ready within the 15-minute preparation budget, including capacity waits. If they cannot, stop and clean up that attempt. Resource settings stay in trusted templates, with no UI override. Recorded runs verify placement and resource controls; active cancellation and recovery checks verify preservation within their tested scope.

### Results and execution status

The run page returns a concise Summary and Grafana link filtered to the attempt and measurement interval. The Summary retains configuration, workflow/workload SHAs, execution status, known gaps and separate cleanup status. A detailed per-runner or exit-code table is not required.

Execution status follows these rules:

| Outcome | Workflow result |
|---|---|
| Every expected runner Job succeeds, required Summary publication succeeds and cleanup is verified | Green |
| Any runner fails, an expected terminal outcome is missing, reporting fails or cleanup is failed/unverified | Red, with the affected outcomes visible |
| Cancellation or timeout | Preserve that outcome; retain available results and attempt cleanup |

A TestRun reaching `finished` is insufficient. Native threshold failures count as runner failures, but do not stop the requested load or the other runners early. Keep `abortOnFail` disabled. The [k6 decision](0003-k6-operator-load-generator.md#thresholds-and-execution-status) explains the per-runner thresholds and why execution status is separate from combined performance assessment.

Developers assess performance manually in Grafana. Green does not prove complete telemetry or a whole-run performance PASS; absent data cannot mean zero failures. Direct Prometheus remote write, native histograms, run/runner identity and accepted upstream dashboard limits follow the [k6 metrics decision](0003-k6-operator-load-generator.md#metrics-and-dashboard-queries). No automated Prometheus evaluator is included.

Grafana uses public HTTPS on the shared ALB and local `Viewer` accounts. The platform maintainer manages those accounts and a separate administrator account; anonymous access and self-registration are disabled. Prometheus stays internal. See architecture for [account access](../architecture.md#human-access) and [DNS/ingress ownership](../architecture.md#dns-and-ingress-ownership).

Metrics survive run cleanup within finite retention/storage; Summary access and retention follow repository settings. Final foundation teardown ends access to in-cluster monitoring. The demo uploads no downloadable result artifacts and retains no k6 logs or stdout summaries. GitHub execution logs do not replace those runner logs, limiting later diagnosis.

### Cleanup and recovery

Omit TestRun `spec.cleanup` so the workflow can observe outcomes and prepare results before resource removal. The sequence is:

1. Observe all expected runner Job outcomes and prepare the available report and Grafana link.
2. Remove the TestRun and its generated resources, then delete the script ConfigMap separately.
3. Verify all tracked objects are gone, then publish one Summary with separate execution and cleanup status.

Cleanup must run after success, failure, cancellation and timeout, including when reporting fails. Stop traffic and retain available results while preserving the original execution outcome. Verify that other runs, namespace controls, Dev services/data, ALB/DNS, cluster and shared monitoring survive.

The [phase budgets](../architecture.md#end-the-run) reserve time for stopping, reporting and cleanup before the hard job timeout. A timeout or `always()` condition does not prove Kubernetes resources were deleted; [force-cancel](https://docs.github.com/en/rest/actions/workflow-runs#force-cancel-a-workflow-run) can bypass `always()`. A lost or force-killed runner may require manual recovery, with visible leftovers and cost exposure. The demo adds no independent cleanup controller or sweeper and promises no hard deletion deadline.

Foundation removal is a separate platform-maintainer task. Bootstrap owns k6 Operator and workflow IAM/EKS/RBAC integration together. Deleting only the Helm release leaves the Terraform-managed access resources. Disabling the complete integration also removes its module-owned generator namespace, so it requires all runs to be cleared first.

Before removing the integration:

1. Stop new runs, stop or finish active traffic, and verify run cleanup while the controller and access still work.
2. Remove the integration through its Terraform owner, including the EKS access entry before its IAM role. Keep independent maintainer access and the shared OIDC provider for remaining consumers and recovery.
3. While EKS remains available, verify fresh role assumption is denied and the former workflow identity cannot create TestRuns after access changes take effect.

Removing access does not stop existing Pods or instantly revoke issued credentials. [Foundation teardown](../architecture.md#foundation-teardown) owns the wider removal order. Integration removal was not exercised and is outside the final demo scope.

## Consequences

- [Benefits and accepted costs](#benefits-and-accepted-costs)
- [Evidence and limits](#evidence-and-remaining-work)

### Benefits and accepted costs

The selected flow puts the workload, launch form and execution results in GitHub, with performance views in shared Grafana. Hosted orchestration avoids another runner fleet and remains outside EKS scheduling. OIDC gives automation its own temporary AWS credentials.

The costs are repository-level access, a public EKS API, reliance on trusted workflow logic, and owned reporting/recovery code. Namespace RBAC leaves a cleanup mistake capable of affecting another run. Shared Dev traffic can also affect results. These limits are acceptable for the trusted-team demo and require explicit validation.

[Another-week work](../../WRITEUP.md#with-another-week) covers private EKS connectivity, API-side admission validation, NetworkPolicy, automated whole-run evaluation and retained k6 logs. A future admission choice must check EKS compatibility and rule coverage; native ValidatingAdmissionPolicy/CEL, Kyverno and Gatekeeper are candidates, not installed controls. Private Grafana access through a VPN with GitHub OAuth SSO is another deferred option, separate from workflow AWS authentication.

<a id="evidence-and-remaining-work"></a>

### Evidence and limits

The published workflow has genuine GitHub-to-AWS-to-EKS evidence. The access check obtained fresh EKS exec tokens more than 15 minutes apart within one six-hour STS session and verified scoped allow/deny operations without creating load resources. This extends the earlier impersonation checks; it does not claim that a persistent watch renewed its credentials or that credentials remain valid beyond the session.

The [validation record](../validation.md#current-workflow-verification) records the workflow outcomes:

- Invalid numeric and target inputs were rejected before load; local checks cover additional source, configuration and scenario-file cases.
- Public/internal Bookinfo runs used matching source SHAs, split total VUs across distinct runners and produced native runner successes or threshold failures without early abort.
- One Summary reported execution and cleanup separately. Upstream Grafana live and fixed-time post-cleanup access passed as Viewer, with display and completeness limits retained.
- Active cancellation removed its own objects while a peer remained running. Force-cancel left live resources; original-UID recovery removed them, preserved unrelated resources and passed a repeat recovery without new load.

Controlled local tests cover timeouts, partial/lost creation, UID conflicts and other failure paths. Those results do not establish equivalent injected AWS faults. The published preparation timer starts before checkout and Python setup; its cross-process handoff passed local checks and hosted Ubuntu execution. Repository configuration also remains outside Git: setup requires twelve Repository Variables, which can change between attempts.

Publication, independent Git-clone checks against retained Dev, hosted timer verification, four videos and human acceptance are complete. Live workflow-integration removal, Grafana credential rotation/revocation and additional fault exercises were not run and are outside the final demo scope.
