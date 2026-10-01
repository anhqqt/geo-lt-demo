# 0001: Test existing Dev services with real dependencies

- [Context](#context)
- [Alternatives](#alternatives)
- [Decision](#decision)
- [Consequences](#consequences)

**Status:** Accepted.

## Context

Load tests should help a team assess a new service or substantial change before release. The selected test follows the real request path, including its dependencies. The prototype also needs a manageable setup, useful results and a clear cleanup boundary.

Bookinfo has four services. A larger application's dependency graph can include other services, databases, caches, queues and managed cloud resources. Recreating that graph for every test adds configuration, credentials, data preparation, readiness checks and recovery work.

The assignment leaves environment and dependency design open. This project interprets the ephemeral environment as temporary k6 resources against a prepared Dev target. Application deployment remains a prerequisite. This is an explicit scope assumption, not a boundary prescribed by the assignment.

## Alternatives

- [Deployment lifecycle](#deployment-lifecycle)
- [Real dependencies and mocks](#real-dependencies-and-mocks)

### Deployment lifecycle

| Option | What it provides | Cost or limitation |
|---|---|---|
| **A. Existing Dev target and dependencies, selected** | Tests the prepared candidate through real integrations; reuses capacity and established application ownership | Requires a ready deployment; shared traffic, deployments and data changes can affect results |
| B. Per-run target with shared real dependencies | Controls the candidate version and configuration without replacing the shared target or copying all dependencies | Adds application deployment, routing, access and recovery; dependencies remain shared |
| C. Per-run target and required real dependencies | Controls versions and starting data together; avoids using shared Dev application instances | Provisions and removes the required dependency graph, with broader permissions and more failure paths |

Option A keeps the workflow focused on bounded load, results and generator cleanup. The Dev deployment process already owns application changes, migrations, credentials and dependency lifecycle. Reusing that process avoids repeating those tasks for every test and keeps run permissions narrow.

For Bookinfo, option B would create a separate `productpage` connected to the shared `details` and `review` services; `review` would still call shared `ratings`. This gives more control over the candidate, but still needs readiness, routing and approved cross-namespace access. For a write workload, deleting the candidate would not undo changes it made to shared dependency data.

Option C would deploy all four Bookinfo services, prepare their data and complete readiness and warm-up before measurement. A more complex service may also require schemas, seed data, cloud identities and managed services. Partial provisioning or deletion can leave chargeable resources, data or access grants; namespace deletion cannot remove every external resource.

C offers a more controlled topology, but fresh synthetic data and different sizing can limit production relevance. Shared nodes and networking can still affect measurements. Reusing selected external dependencies reduces provisioning work while retaining some sharing. The setup time and cost need measurement; no speed or cost saving is assumed.

### Real dependencies and mocks

All three deployment options above use real dependencies. That choice exercises the selected integration path. The assignment also permits mocks and stubs, which can help diagnose one service under controlled response, latency and failure conditions.

A mock measures behavior against its simulated contract. It can supplement this test, but would not replace the selected real-dependency path. Bookinfo supplies real service calls with built-in synthetic data, so the demo does not need a database merely to demonstrate dependency handling.

## Decision

- [Preparation and run ownership](#preparation-and-run-ownership)
- [Bookinfo baseline and data](#bookinfo-baseline-and-data)
- [Interpreting results](#interpreting-results)
- [Application and IaC ownership](#application-and-iac-ownership)

### Preparation and run ownership

The platform maintainer prepares the candidate and required real dependencies through the normal Dev deployment process. That includes configuration, credentials, resource settings, readiness and data. The load workflow validates target syntax and bounded inputs, then manages only its generator resources.

Self-service starts once the application is ready. If the separate deployment process requires a ticket, this choice does not remove that ticket. The [setup guide](../setup.md) still covers the initial foundation, monitoring and Bookinfo deployment; using an existing target during a run does not remove initial setup from the deliverable.

| Owner | Responsibility | Per-run cleanup |
|---|---|---|
| Platform maintainer | Dev application, dependencies, data and shared AWS foundation | Preserved |
| Foundation bootstrap | Generator namespace, ServiceAccounts, RBAC and shared monitoring | Preserved |
| Run workflow | One TestRun, script ConfigMap and associated helper/runner resources | Removed and checked for leftovers |

The same boundary applies after success, failure, cancellation, timeout and recovery. Preserve other runs, all Dev services/data, ALB/DNS/TLS, EKS/node groups, monitoring volumes and retained results. Run cleanup must never reset a shared database, flush a shared cache or purge a shared queue.

Final removal of the assignment foundation is a separate task. [ADR 0004](0004-github-actions-self-service-workflow.md#cleanup-and-recovery) defines reporting order, cleanup verification and recovery limits.

### Bookinfo baseline and data

[Bookinfo](https://istio.io/latest/docs/examples/bookinfo/) was chosen because its four services give the prototype a small, real dependency graph. The selected path is:

- `productpage` calls `details` and the local `review` service.
- `review` uses the upstream `reviews-v2` image and calls `ratings`.

Version v2 includes ratings calls; v1 bypasses them. The application does not require Istio, and this demo installs no service mesh. Each service has one replica on `main`, without an HPA; generators use separate hosts through the `load-test` node group.

The local Service and Deployment are named `review`, with generated Pod names beginning `review-` and no version suffix in the Deployment name. Upstream image, API and configuration identifiers retain `reviews`. Productpage uses `REVIEWS_HOSTNAME=review` to reach the local Service.

Use built-in synthetic data and GET-only traffic. Details' external-book-service mode is disabled, and the selected ratings implementation keeps data in memory. This workload needs no database, cache, queue, per-run seed job or data deletion. Readiness checks must include real dependency calls; process health alone does not establish that the path works.

Ratings still exposes an upstream [POST route](https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/src/ratings/ratings.js), with no write-disable setting. Keep ratings internal and avoid concurrent writes during the test. Run automation has no application mutation or exec access, but those Kubernetes permissions do not block HTTP writes. Read-only testing depends on the trusted workload and Dev usage; network enforcement is not claimed.

### Interpreting results

Each Bookinfo demo iteration sends one GET to the supplied productpage URL and asserts only `status === 200`. Retain latency, achieved throughput, non-200 responses or transport failures, native runner diagnostics and execution failure reporting. Developers assess the Summary and Grafana manually under the [k6 decision](0003-k6-operator-load-generator.md#thresholds-and-execution-status).

The [productpage handler](https://raw.githubusercontent.com/istio/istio/1.26.3/samples/bookinfo/src/productpage/productpage.py) can render a page even when a dependency fails. HTTP 200 therefore does not prove complete page or business correctness. Content and dependency-content assertions are deferred. A green workflow is not an automated whole-run performance verdict.

Retain the workload revision, chosen public/internal route, configured total VUs, HTTP checks and measured results. The assessment applies to the observed candidate/dependency configuration, data, capacity and measurement interval. The [request paths](../architecture.md#send-traffic) include different network components, so the chosen route is part of the result.

Shared Dev can receive other traffic and deployments; a reserved test window is not guaranteed. These measurements cannot isolate the target from dependency behavior or establish production capacity. Release conclusions need evidence about the conditions in which the test ran. Production promotion remains a separate process.

Automated capture of deployed application/dependency versions, configuration and concurrent activity is deferred, along with automated whole-run evaluation. The demo adds no environment snapshots, activity collector or additional permissions for that purpose. Pinned deployment images and a recorded workload SHA alone do not prove the shared environment stayed unchanged throughout a run.

### Application and IaC ownership

The [Terragrunt decision](0005-terragrunt-iac-orchestration.md) separates foundation and application changes from generator runs. Bookinfo has one pillar unit at `platform/pillars/bookinfo/terragrunt.hcl` within its environment/region, backed by `infra/terraform-modules/bookinfo`. Its namespace and four services share one state.

The source module contains four service children, four Helm releases and a shared library chart. Service charts own pinned images and resource defaults; the normal leaf exposes no image inputs. The charts and Terraform overrides own CPU/memory settings. Bounded load samples establish tested operating points, not sustained application capacity.

The source root and leaf currently use local module paths. Published immutable service-module releases are outside this demo. A later pillar can include supporting resources it needs, but S3/cache resources are examples, not part of Bookinfo. The run identity has no destroy authority over foundation or shared-service states.

## Consequences

- [Benefits and accepted limits](#benefits-and-accepted-limits)
- [Evidence and limits](#evidence-and-remaining-work)

### Benefits and accepted limits

The demo covers Bookinfo. The [scenario-registration guide](../setup.md#add-a-test-scenario) supports another prepared service with a self-contained script and dropdown entry. Deploying or demonstrating a second application and general service/data onboarding remain outside the [accepted scope](../specification.md#exclusions).

The workflow can focus on load generation and cleanup while testing real Dev integrations. Application ownership remains with the existing deployment process, and each run avoids provisioning the dependency graph. Shared infrastructure still costs money between tests, and the initial cloud setup remains required.

The trade-off is a deployment prerequisite and less control over shared conditions. Tests can affect other teams through shared services, even with separate generator hosts. Repeatability and release relevance depend on the deployed versions, data and concurrent activity; a clean generator teardown does not resolve those limits.

<a id="evidence-and-remaining-work"></a>

### Evidence and limits

The initial Bookinfo checks established four Ready services, pinned images and configured resources, real dependency calls, internal/public requests, shared ALB/DNS/TLS and probe cleanup. Later published workflow runs exercised both routes with real application load, native runner diagnostics, retained metrics and verified run cleanup. The [validation record](../validation.md#current-workflow-verification) preserves passing runs, threshold failures and a run affected by a concurrent deployment.

The current Productpage baseline uses 1000m CPU and 1024Mi memory for requests and limits. At that baseline, 20-VU public/internal and 40-VU internal samples passed; the 80-VU internal sample failed latency while completing its duration and cleanup. These short runs do not establish a sustained capacity limit or remove the shared-environment constraints above.

Chart-default, optional-limit and chart-layout checks passed locally. The final Bookinfo plan still proposes one in-place Helm values update whose parsed values match the deployment; no apply was performed for that textual difference. Bookinfo exposure removal/restoration is user-confirmed without an agent-executed trace. Full-pillar destruction was not run and is outside the final demo scope.

The published submission includes implementation, selected evidence and four videos, with independent Git-clone checks and human acceptance. [Setup verification](../setup.md#verify-the-setup) and the [workflow decision](0004-github-actions-self-service-workflow.md#evidence-and-remaining-work) distinguish demonstrated cleanup and preservation from excluded fault and lifecycle exercises.
