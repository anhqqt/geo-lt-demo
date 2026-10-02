# Validation

- [Validation summary](#validation-summary)
- [Recorded checks](#recorded-checks)
- [Acceptance coverage](#acceptance-coverage)
- [Evidence and reproduction](#evidence-and-reproduction)

## Validation summary

The final AWS self-service demo is complete and accepted within the scope below. Real public/internal Bookinfo runs, GitHub OIDC and token renewal, rejected inputs, retained metrics and UID-scoped cleanup have execution evidence. Upstream Grafana reconciliation and live/post-cleanup Viewer checks passed too.

This record combines several development checkpoints in `ap-southeast-1`, using EKS `1.36`. They span several source revisions. Each result below retains its tested configuration and limits.

The package has been published and checked from independent Git clones. Hosted runs verify the preparation timer handoff, and [four demo videos](demo-video.md) show success, rejected inputs, HTTP failure and cancellation with an active peer.

Human acceptance was recorded for package `e72e2c5191ae5d7084103c5e88c8dbbe51ba31aa` and its private-repository access handoff. The review record was published at `f30adebe5da9c40e12629b3ac2dde151a7a27d73`. These historical identifiers describe that review; later documentation and DNS configuration edits were not part of it.

A separate recipient-account playback check was not independently run. Additional fault and decommission exercises are outside the final scope, with their evidence limits retained below.

- **Passed** means the named check passed within its recorded scope.
- **Failed** means the check or workload did not meet its recorded criterion. An expected workload failure can still demonstrate correct reporting and cleanup.
- **Not run** means the named check has no execution result here.

The method matters too: local rendering, an AWS runtime check and a human confirmation provide different evidence. The [acceptance groups](#acceptance-coverage) cover the demonstrated final scope defined in the [specification](specification.md#required-evidence). Excluded checks have no claimed pass result.

## Recorded checks

- [Foundation and infrastructure](#foundation-and-infrastructure)
- [Bookinfo and request paths](#bookinfo-and-request-paths)
- [Controllers and access](#controllers-and-access)
- [Monitoring and results storage](#monitoring-and-results-storage)
- [Later source checks](#later-source-checks)
- [Current local implementation checks](#current-local-implementation-checks)
- [Current workflow verification](#current-workflow-verification)

### Foundation and infrastructure

**Method: local validation and authorized AWS execution.** The foundation records cover real applies, refreshed plans and bounded runtime probes.

| Check | Recorded result | Limit |
|---|---|---|
| Backend and Global units | Passed: backend protections, lock contention/release, separate state keys, OIDC provider and delegated DNS zone | Actual alternate-account credentials and injected state recovery were not tested |
| DNS and regional Core | Passed: parent/child DNS delegation, VPC routing inventory, available NAT and issued ACM certificate; final Core plans reported no changes | Route inventory alone does not prove packet delivery; later cluster probes cover bounded egress |
| EKS and placement | Passed: cluster/addons ready, private nodes, independent maintainer access, DNS/HTTPS probes from all three groups and rejection by an untolerated taint | These probes establish connectivity and placement, not application load capacity |
| EBS storage | Passed: gp3 provisioning, retained-PVC reuse after Pod recreation, then absence of the probe PVC, PV and EBS volume | Node replacement and AZ recovery were not exercised |

Account rejection used a controlled fixture with a deliberately mismatched expected account ID. It did not use credentials from a second account.

Final foundation teardown was not exercised and is excluded from demo validation. The [maintainer procedure](setup.md#remove-the-foundation) remains available. The reviewed destroy plans and removal of a former empty backend do not establish teardown of the populated foundation.

### Bookinfo and request paths

**Method: AWS/Kubernetes reads and finite HTTP probes against a deployment prepared by the platform maintainer. Result: Passed.**

- All four service Deployments were Ready, with unchanged Pod identities and zero restarts over the recorded observation interval of more than ten minutes.
- Requests from the application containers verified `productpage → details/review` and `review → ratings`, including the expected synthetic responses.
- A temporary non-k6 Pod on a `load-test` node reached productpage through internal Service DNS and public HTTPS. Both returned HTTP 200; the probe was then deleted and confirmed absent.
- Bookinfo and Grafana used the same healthy ALB. DNS, certificate verification and HTTP-to-HTTPS redirect checks passed. Grafana health and anonymous-access restrictions remained intact.

The historical bounded sequence stayed within 32 foreground application/access requests. It demonstrates readiness and connectivity; later application load is recorded under [current workflow verification](#current-workflow-verification). The recorded no-change Bookinfo plan predates the [later source changes](#later-source-checks).

Exposure removal/restoration is **human-confirmed** by the platform maintainer. No detailed recovery trace was supplied. The recorded exposure-off and pillar-destroy plans were inspected without applying them; full-pillar destruction remains unrun.

### Controllers and access

**Method: bounded AWS probes, controller observations and Kubernetes permission checks.**

| Check | Recorded result | Limit |
|---|---|---|
| Autoscaler | Passed: two inert Pods triggered load-test capacity from one node to two, then back to one; probe objects and the terminated node's root volume were absent afterward | No application traffic; maximum capacity and quota exhaustion were not tested |
| Temporary ALB/DNS lifecycle | Passed: dedicated controller roles created and removed a temporary endpoint; original zone records and certificate remained | Used the earlier annotation-based discovery configuration; retained endpoint removal under the later configuration remains unverified |
| Workflow permission boundary | Passed: deployed IAM/EKS metadata and 43 Kubernetes permission cases through impersonation | Impersonation bypasses GitHub OIDC and IAM-to-EKS authentication |
| k6 Operator lifecycle | Passed: an arithmetic-only TestRun completed with two runners; tracked run objects disappeared and namespace controls remained | No application HTTP, metric export or GitHub workflow was exercised |

The k6 smoke recovered from startup retries. During its observation interval, the cluster state version changed and the writer was not identified. A comparison found unchanged managed resources, outputs and lineage. This supports resource preservation, without establishing that every state object stayed unchanged.

These historical controller probes did not test genuine GitHub authentication or workflow cancellation. The [current verification](#current-workflow-verification) records later coverage; live k6 integration removal remains unrun. The [workflow access design](architecture.md#workflow-access) describes the intended identity path.

### Monitoring and results storage

**Method: a short k6 probe against Prometheus readiness, authenticated Grafana queries and monitoring Pod recreation.**

| Check | Recorded result | Limit |
|---|---|---|
| Metric transport | Passed: two runners exported separate native histograms, with common run tags and distinct runner identities; Grafana could query both | Traffic targeted Prometheus readiness, not Bookinfo |
| Storage and persistence | Passed: Prometheus 20Gi and Grafana 1Gi gp3 volumes; metrics and temporary Grafana data survived separate Pod recreations | Same retained volumes; no node/AZ recovery or monitoring uninstall |
| Public Grafana access | Passed: DNS/TLS, health, anonymous rejection and Viewer query access; a Viewer folder edit was denied | These API checks do not establish dashboard accuracy |
| Probe cleanup | Passed: tracked k6 objects, temporary Grafana user/folder and local forwards were removed; shared monitoring and namespace controls remained | This cleanup was exercised outside the planned GitHub workflow |

The metric smoke exposed a tag-precedence problem: Operator CLI tags replaced tags supplied only in the script. The corrected probe passed the run tags through TestRun arguments and verified the resulting series. Later Bookinfo runs verified the workload preserves those tags and distinct runner identities.

An earlier Grafana Viewer check failed immediately after a folder was created. A later attempt passed after a short retry without changing its permissions. The included evidence retains both the earlier failure and later success.

The historical public Grafana checkpoint had no dashboards. A custom dashboard was later deployed and checked against its source, controlled queries and retained Bookinfo metrics. Those browser checks used Admin.

Upstream dashboard 18030 revision 8 has since been applied and read back, followed by a no-change bootstrap plan. A separate Viewer run verified live data and retained results after cleanup. The current workflow section below records that result without relabeling the earlier custom-dashboard checks.

### Later source checks

**Method: isolated local Terraform/Helm validation. Result: Passed for the recorded follow-ups.** These checks themselves made no AWS changes; later deployment evidence is identified separately.

- Bookinfo optional resource limits, chart defaults and Terraform overrides passed their focused checks.
- Chart relocation passed Terraform cases, real Helm renders, expected input rejections, strict chart lint and external-chart override checks.
- ALB tag/default changes passed their scoped local checks. Earlier failed chart renders were corrected and rechecked in these follow-ups.

These local results do not extend the earlier AWS snapshot to the final source. The [naming ADR](decisions/0006-aws-resource-naming-and-state-layout.md#evidence-and-remaining-checks) adopts generated node-group suffixes and exact `<cluster_name>-noderole-<group>` IAM roles. Earlier deployment records tested the previous naming convention.

The technical closure check found fresh cluster and bootstrap plans with no changes. Bookinfo showed one in-place Productpage Helm update: the old and proposed values parsed to equal YAML objects, including all 16 Ingress annotations, but quoting and key order differed. No Bookinfo apply ran for that textual difference. These checks do not prove a fresh grouped bootstrap.

The simplified three-layer apply sequence passed a provider-free dependency-ordering fixture. A fresh grouped Platform deployment on AWS was not run and is outside final acceptance; the setup guide labels that limit.

### Current local implementation checks

Credential-free development validation passed Global/Core/cluster source and output checks, 27 cluster input cases, 14 Terragrunt rendering cases, 50 Bookinfo Terraform cases, 57 Helm renders and 12 Helm rejection cases. The standalone Bookinfo chart/value checks passed too. Bootstrap module checks and the former custom-dashboard Helm render checks passed locally; those dashboard checks predate the restoration of upstream provisioning.

Both workflow structure checks and actionlint 1.7.12 passed. The former custom-dashboard expressions passed controlled tests with Prometheus 3.15.0: unequal runner traffic gives 99.4% success and 0.6% failure, merged native histograms produce the expected p95, and absent/zero-denominator runs remain empty. A missing runner can still leave an observed 100% ratio, so the dashboard cannot establish completeness. These fixtures generate no AWS traffic.

The dashboard derives from [18030 revision 8](https://grafana.com/api/dashboards/18030/revisions/8/download), upstream SHA-256 `cfdb2e25f27373083ae477b501c606c4a84840f9d00a60f9999e99e690c4f182`. The monitoring [values template](../infra/terraform-modules/platform-bootstrap/modules/kube-prometheus-stack/values.override.yaml) selects it by `gnetId` and revision. No dashboard JSON is stored in this repository. The later AWS reconciliation applied this source and verified its readback. The accepted scope uses the upstream dashboard with documented display limits; exhaustive numerical fixtures and custom query corrections are outside final acceptance.

The k6 2.2.0 CLI inspected the included workload at 21 VUs and 60 seconds, showing a 30-second graceful stop, disabled redirects and the fixed thresholds. This was inspection without traffic. Later Bookinfo runs executed the pinned image and exposed two runner series at ten VUs each.

Focused runtime validation passed 57 local test methods covering inputs, native rendering, workflow subprocesses, ownership, lifecycle failures, recovery and Summary handoff. These controlled development checks are kept outside this submission. The development harness also passed 14 checks.

The local timer-order change passed actionlint, syntax checks, a cross-process timer smoke, five preparation cases and the 57 regression methods. An initial smoke using macOS Python 3.9.6 failed because its monotonic origin differed from the verifier; rechecks with Python 3.14.7 and 3.10.11 passed without production-code or assertion changes. Controlled clocks and API doubles do not establish AWS timeout behavior.

Hosted run [37039318261](https://github.com/anhqqt/geo-lt-demo/actions/runs/37039318261) subsequently verified that handoff on Ubuntu 24.04 at published revision `9e35a86`. The timer step preceded checkout and Python setup; lifecycle preparation consumed the timing file successfully. This does not exercise an actual timeout.

### Current workflow verification

- [Recorded demo and package checks](#recorded-demo-and-package-checks)
- [Current capacity samples](#current-capacity-samples)
- [Access, rejection and recovery](#access-rejection-and-recovery)
- [Earlier performance and result checks](#earlier-performance-and-result-checks)
- [Upstream dashboard and Viewer check](#upstream-dashboard-and-viewer-check)

The [packaged runtime commit `a81a194`](https://github.com/anhqqt/geo-lt-demo/commit/a81a1941eef9ac5b23f45ed8249db712958d4e5a) contains the same workflows, policy, workloads and Python scripts as recorded revision `cc64599`. The table below retains the original SHAs to identify which behavior each checkpoint tested.

| Historical revision | Evidence context |
|---|---|
| `41e1934`, then `1e117d9` | Initial workflow/runtime, followed by the duplicate-Summary fix |
| `2fa53c7` | Accepted Bookinfo latency threshold `p(95)<1000`; HTTP-200 checks remain `rate>=0.99` |
| `66988dc`, published in `9e35a86` | Preparation timer starts before checkout; isolated Ubuntu reproduction covers the published infrastructure/documentation package |
| `cc64599` | Recorded URL-only workflow: a complete HTTP or HTTPS target URL, with no target-mode input; lifecycle, workload and infrastructure paths unchanged from `9e35a86` |

Tests run against existing Dev Bookinfo in `ap-southeast-1`, EKS `1.36`. The current accepted Productpage requests and limits are `1000m` CPU / `1024Mi`; `obser` uses `t3a.medium`. Hold that baseline fixed while load changes. Historical runs at `200m`, `500m` or a `500ms` threshold retain their original configuration and outcome.

#### Recorded demo and package checks

The [video guide](demo-video.md) maps all four recordings to their Actions runs, source and fixed-time results. At `cc64599`, the success run and surviving cancellation peer succeeded; the missing-route run failed; all four executed runs report cleanup verified. Five numeric rejections and a separate unsupported-protocol rejection failed validation with the load job skipped. The cancellation video uses 20 VUs / 300s / 2 runners per run.

The success run's hosted steps started the preparation budget before checkout and Python setup. An independent clone of `cc64599` passed actionlint 1.7.12, Python compilation, six focused URL/input regression methods and document checks. The development regression suite was invoked separately against the clone; its files are not part of the submission. The unchanged infrastructure and lifecycle files retain the earlier isolated Ubuntu clone evidence. Blank-account bootstrap, fresh grouped Platform creation and ZIP reproduction remain unverified.

After the recorded runs, a fresh maintainer read found no TestRuns, Jobs, Pods or Services in `k6-runners`, and the original run ConfigMaps were absent. Bookinfo, monitoring and controllers were Ready; monitoring PVCs were Bound. This later read proves their observed final state. The videos and prior inventories provide the separate during-run preservation evidence.

The approved Grafana Viewer account could still query the exact success, HTTP-failure and surviving-peer intervals after cleanup, with dashboard editing denied. Prometheus reported `10d` retention. This readback is distinct from the maintainer Grafana session visible in the videos. Earlier exact live Viewer proof also exists at [run 37046438065](https://github.com/anhqqt/geo-lt-demo/actions/runs/37046438065), with queries observed before runner termination and all 12 recorded run UIDs absent afterward.

#### Current capacity samples

| Check | Observed result | Evidence limit |
|---|---|---|
| [Current public 20 VUs](https://github.com/anhqqt/geo-lt-demo/actions/runs/37006458750), 60s, two runners | Succeeded: p95 288.71 / 295.43ms, all 6095 HTTP-200 checks passed, about 101.36 requests/s; cleanup verified | Productpage `1000m/1024Mi`, runtime `2fa53c7`; one short sample |
| [Current internal 20 VUs](https://github.com/anhqqt/geo-lt-demo/actions/runs/37006993089), 60s, two runners | Succeeded: p95 353.04 / 349.97ms, all 5444 HTTP-200 checks passed, about 90.55 requests/s; cleanup verified | Same baseline/revision; short samples do not establish sustained capacity |
| [Internal 40 VUs](https://github.com/anhqqt/geo-lt-demo/actions/runs/37007994169), 60s, two runners | Succeeded: p95 771.39 / 845.52ms, all 6145 HTTP-200 checks passed, about 102.05 requests/s; cleanup verified | `1000m/1024Mi`, same runtime; one short sample |
| [Internal 80 VUs](https://github.com/anhqqt/geo-lt-demo/actions/runs/37008439861), 60s, two runners | Failed latency: p95 1.49 / 1.21s; all 6151 HTTP-200 checks passed; about 101.81 requests/s; cleanup verified | Throughput plateaued while latency rose. 40 passed and 80 failed this criterion; no exact or sustained capacity boundary is established |

The public and internal 20-VU baseline runs each had one Summary, unchanged Bookinfo identities/resources during load, and absent run objects afterward. Two ten-VU series and retained post-cleanup results were visible through their exact Grafana links. These observations used Admin and the former custom dashboard.

#### Access, rejection and recovery

| Check | Observed result | Evidence limit |
|---|---|---|
| [Genuine access and renewal](https://github.com/anhqqt/geo-lt-demo/actions/runs/36984509497) | Passed allowed/denied permission checks and EKS exec-token renewal after more than 15 minutes in one STS session | No load; does not prove live rejection of a forbidden OIDC subject |
| [Active cancellation](https://github.com/anhqqt/geo-lt-demo/actions/runs/37007417162) with [live peer](https://github.com/anhqqt/geo-lt-demo/actions/runs/37007421602) | Cancellation requested with both runs active; first run cleanup preserved peer root UIDs and two Running runners | Each requested 20 VUs / 180s / 2 runners; does not establish immediate stop latency |
| Forced orchestration stop and recovery of the same peer | GitHub was cancelled while its TestRun and two runners remained active; original-UID maintainer recovery deleted all leftovers; repeat recovery verified absence | Recovery requires the independent maintainer identity and original root UIDs; it creates no new load |
| Rejected requests | Seven historical hosted requests rejected before the load job: VUs below/above bounds, short duration, too many runners, fractional VUs, public HTTP and URL fragment | The public-HTTP rejection used the former HTTPS-only rule; HTTP is now accepted. Other boundary/source/configuration cases were checked locally; no maximum-duration or maximum-VU cloud test |
| Recovery and preservation | Original-UID no-op and real ConfigMap-only deletion/repeat passed; persistent namespace/controls, monitoring volumes and shared services preserved | ConfigMap-only recovery does not prove stopping a lost live TestRun |

The seven historical hosted rejection runs are [VUs 19](https://github.com/anhqqt/geo-lt-demo/actions/runs/36996233152), [public HTTP](https://github.com/anhqqt/geo-lt-demo/actions/runs/36996259900), [VUs 1001](https://github.com/anhqqt/geo-lt-demo/actions/runs/37003509017), [duration 59](https://github.com/anhqqt/geo-lt-demo/actions/runs/37003512590), [runners 11](https://github.com/anhqqt/geo-lt-demo/actions/runs/37003516393), [fractional VUs](https://github.com/anhqqt/geo-lt-demo/actions/runs/37003520255), and [URL fragment](https://github.com/anhqqt/geo-lt-demo/actions/runs/37003523386).

#### Earlier performance and result checks

| Check | Observed result | Evidence limit |
|---|---|---|
| [Public 20 VUs](https://github.com/anhqqt/geo-lt-demo/actions/runs/37003132349) and [internal 20 VUs](https://github.com/anhqqt/geo-lt-demo/actions/runs/37003464924), 60s, two runners | All HTTP-200 checks passed; p95 roughly 731 to 757ms; failed the then-current 500ms threshold; cleanup verified | Historical `500m` baseline and criterion, commit `1e117d9`; about 43 requests/s, not a sustained production capacity guarantee |
| [404 response](https://github.com/anhqqt/geo-lt-demo/actions/runs/37003818672) | Both runners completed the requested duration, failed HTTP checks and exited 99; cleanup verified | Deliberate missing path; not a Productpage capacity test |
| [Cancellation after traffic](https://github.com/anhqqt/geo-lt-demo/actions/runs/37003822821) | Workflow cancelled and removed its resources while the 404 peer remained | Traffic had already ended, so this case does not prove early traffic termination |
| [Rollout-overlap failure](https://github.com/anhqqt/geo-lt-demo/actions/runs/37004257505) | New 1s threshold passed, but HTTP-200 rates were only 6.48% / 6.27%; cleanup verified | Productpage changed during the run; a subsequent probe returned 503. Excluded from stable-baseline capacity conclusions |
| Retained distributed results | Two ten-VU runner series; exact run/time links; dashboard request estimate 2685.6667 matched displayed 2686 for the public baseline window; unknown/empty queries had no data | Prometheus window estimate differs from native request totals; browser access for that checkpoint was Admin |

#### Upstream dashboard and Viewer check

The monitoring update replaced inline custom dashboard data with upstream catalog provisioning and removed the former datasource interval override. The apply changed one Helm release, with no additions or deletions; a fresh bootstrap plan reported no changes. Grafana, Prometheus and the monitoring operator were Ready, and both PVCs stayed Bound. The shared ALB and node-group configuration remained unchanged.

[Viewer run 37020793556](https://github.com/anhqqt/geo-lt-demo/actions/runs/37020793556) used public Bookinfo, 20 VUs, 60 seconds and two runners on runtime `2fa53c7`. It succeeded: native p95 was 403.77ms / 435.79ms, all 5771 HTTP-200 checks passed, and combined throughput was about 95.96 requests/s. The Summary appeared once and reported execution succeeded and cleanup verified. All 12 captured run objects were removed; all 48 shared object UIDs, ALB identity, node groups and state versions were preserved across the run.

The approved Viewer account could read the dashboard and datasource, had no administrator role and could not edit the dashboard. It saw live data and two distinct ten-VU runner series. The post-cleanup Summary link kept the exact run and absolute interval through navigation and reload.

Opening the live link before the new Test ID appeared initially selected All; the selection was then narrowed to the run. Wait for the new Test ID before selecting it during a demonstration. The upstream failure stat displayed No data, which was not treated as zero or PASS. Its average-VU and rounded check-rate panels do not certify distributed totals or whole-run results.

Authenticated dashboard readback and the no-change plan establish source/deployment agreement for this checkpoint. The dashboard API reported that it was not provisioned, so that API flag is not used as evidence of file provisioning.

Native thresholds apply per runner. Grafana supports manual interpretation; its upstream panels do not replace runner verdicts or certify metric completeness or whole-run performance.

The four videos and subsequent package checks are listed above. Cloud timeout/capacity-exhaustion faults, monitoring AZ recovery and integration access removal were not exercised and are outside final acceptance.

## Acceptance coverage

The table maps recorded checks to the [final evidence groups](specification.md#required-evidence). The user accepted the demo, submission artifacts and Git-clone delivery scope. Each group is complete within the scope shown; linked checks above own the detailed observations and limitations. Deliberate workload failures retain their failed execution results while demonstrating failure handling and cleanup.

| Criterion | Evidence available | Final status and limits |
|---|---|---|
| EVID-01 | Foundation, public/internal workflow success, upstream monitoring reconciliation, Viewer results and UID-scoped cleanup in [current verification](#current-workflow-verification) | Accepted: demonstrated AWS flow, with dashboard and retention limits |
| EVID-02 | Real HTTP-404 and latency-threshold failures ran their requested durations and cleaned up; local missing/failed Job, reporting and cleanup fault checks | Accepted: live failure handling and recorded local supplements; no claim of every cloud failure mode |
| EVID-03 | Genuine OIDC/renewal, hosted numeric and unsupported-protocol rejections, local source/input checks, real public/internal routes, generator placement and 20 total VUs | Accepted: scoped access and bounded requests; forbidden OIDC-subject and capacity/startup faults were not injected live |
| EVID-04 | Real active cancellation, parallel-run preservation, force-stopped orchestration with live leftovers, original-UID recovery and repeat cleanup | Accepted: demonstrated cancellation and recovery; hosted timeout/capacity-exhaustion faults and precise stop latency were not measured |
| EVID-05 | Real foundation creation, workflow-owned resource lifecycle, IaC/source checks and shared-resource preservation | Accepted: reusable IaC and run cleanup; full-pillar destruction, integration removal and final teardown are outside scope and unrun |
| EVID-06 | Published package, independent Git-clone checks, hosted timer handoff, retained results and cleanup, four recordings and a three-page WRITEUP render | Accepted: Git-clone delivery and private-repository access handoff; independent recipient-account playback and ZIP reproduction were not run |

No additional fault, capacity, repeated-bootstrap or decommission exercise is required to complete this accepted demo. Those exclusions do not establish a sustained capacity guarantee or prove an untested recovery path. [With another week](../WRITEUP.md#with-another-week) contains optional improvements.

## Evidence and reproduction

- [Included evidence and its limits](#included-evidence-and-its-limits)
- [Recheck and human review](#recheck-and-human-review)

### Included evidence and its limits

The Git history groups the final submission files by topic. Historical run and review SHAs in this record and the JSON bundle remain unchanged and are outside that history. The bundle's `source_history` maps the recorded runtime to its new commit and lists the paths verified as identical.

The [selected observation bundle](evidence/validation-observations.json) retains small excerpts from existing development outputs. Each selection identifies its original artifact, SHA-256 and JSON location. These are historical observations, not tests rerun while preparing this document.

The bundle also identifies the development reports used for this summary. Their full narratives and private cloud logs are not included here. A source hash identifies the original file; it does not make an omitted artifact independently inspectable. Claims without an included output remain report-based evidence.

The development reports identify tested working-tree files through source manifests; those manifests and source snapshots are not bundled here. Several checks used uncommitted source, so a base commit alone cannot reproduce them. The current workflow section identifies published runtime revisions and run URLs. Historical infrastructure evidence spans several revisions; acceptance applies only to the demonstrated scope above.

The submission excludes Terraform state, raw plans, credentials, kubeconfig and authentication data. The selected outputs are limited to check results needed to assess the claims above.

### Recheck and human review

The [setup guide](setup.md) owns deployment and readiness commands. Its [tool table](setup.md#tools) distinguishes repository pins from recorded client versions. Workflow runtime and recovery scripts are included. Development-only validators, their dependencies and fixtures are excluded from the submission; the historical results above retain their original scope.

The final demo and private-repository access handoff have human acceptance. Its scope includes the published implementation, recorded scenarios and Git-clone checks against retained Dev. Independent recipient-account playback, repeated blank-account bootstrap and decommission were not performed.

For a later authorized change, record its source, environment, inputs and outcomes separately, then repeat the affected checks. Preserve execution, manual performance assessment and cleanup as distinct results. Existing acceptance does not certify a changed deployment or an untested runtime path.
