# Design choices and trade-offs

The final demo is published and accepted, with independent Git-clone checks, hosted timer verification and four recorded scenarios. [Validation](docs/validation.md#current-workflow-verification) records OIDC, Bookinfo load, retained results and cleanup, including failures and limits.

## Context and assumptions

I assume a shared Dev environment with the target and its dependencies ready before testing. Teams can request load, read results and clean up test resources without a setup ticket each time.

[Bookinfo](https://istio.io/latest/docs/examples/bookinfo/) provides four services with real dependency calls. The test requests its product page using built-in synthetic data, without an external database or per-run seeding. The demo runs in one AWS Dev account in Singapore.

## Key decisions

### Developer interface: GitHub Actions

GitHub Actions keeps scripts, the run form and reports with the repository. Developers choose a scenario, full target URL, total virtual users, duration and runner count. Each run returns a summary and Grafana link, reporting execution and cleanup separately.

- Jenkins offers finer job permissions, but adds a controller, plugins and maintenance.
- Argo Workflows offers Kubernetes workflow controls, but adds a controller and another UI to secure.

I chose GitHub Actions to keep the developer flow small. Repository-level permissions and explicit cancellation and cleanup logic are accepted costs. The workflow and workload use the same default-branch revision.

### Ephemeral resources: k6 only

Each run creates and removes its own k6 resources in a persistent generator namespace. Bookinfo, the cluster, namespace controls and monitoring stay in place. Initial setup and final foundation teardown belong to the platform maintainer.

Deploying the target per run, or recreating it with all dependencies, would give more control over the candidate. Both add deployment, readiness and recovery work. Reusing Dev avoids dependency provisioning, at the cost of less control over other traffic and deployments.

Real dependencies exercise the selected request path. Mocks could help diagnose one service, but would measure a simulated dependency contract.

### Namespace choice: one shared namespace

Platform bootstrap creates one fixed generator namespace, its ServiceAccounts and RBAC. Runs manage only their k6 objects:

- **Fixed namespace:** access controls stay outside the run lifecycle. The workflow cannot create or delete namespaces or change those controls.
- **Namespace per run:** each test gets a separate object boundary, per-run access rules and a cleanup boundary. Each run also needs namespace provisioning, access setup and verified deletion, using broader permissions or a separate provisioner.
- **Accepted risk:** shared-namespace RBAC does not enforce ownership between runs. Cleanup must track run-owned objects and preserve other tests and the namespace.

For this trusted-team demo, I accepted reliance on object tracking for less setup and narrower workflow permissions. Separate namespaces support per-run controls, but [network and compute isolation need additional controls](https://kubernetes.io/docs/concepts/security/multi-tenancy/).

### Execution environment: EKS

I chose EKS for workload portability and placement controls. Applications, monitoring and generators use separate node groups. Reusing the Kubernetes manifests elsewhere would still require changes to AWS identity, networking and storage integrations.

- ECS would provide container scheduling with direct AWS integration, using task definitions and AWS service discovery.
- EC2 with Docker Compose would have fewer orchestration components, but require more host setup and recovery automation.

EKS adds cluster add-ons and access configuration to maintain. A future GitOps workflow is possible, but is outside this demo.

### Infrastructure: Terragrunt layers and separate states

Terraform defines resources. Terragrunt shares configuration and connects outputs between deployment units. I chose it to keep account settings, regional infrastructure and application changes separate:

- Global owns account-wide identity and public DNS.
- Core owns regional networking and the shared TLS certificate.
- Platform has separate units for the cluster, persistent platform setup and application pillars such as Bookinfo.

Separate states let Bookinfo updates be planned apart from the network and cluster. Shared includes keep providers, backends and tags consistent; dependencies declare required outputs.

Shared-resource changes still affect consumers. Dependency ordering, output changes and recovery need care.

Direct Terraform supports separate states too, with fewer tools. It leaves more backend configuration and coordination between roots to maintain. CDKTF lets teams use a familiar programming language, but adds a runtime and synthesis step. Its [upstream project is archived](https://github.com/hashicorp/terraform-cdk).

Public modules cover suitable standard resources; local modules compose the cluster, platform setup and Bookinfo. The layout allows separate environment accounts, but only Dev is demonstrated. Published module releases are outside this demo.

The trade-off is another CLI and configuration layer to learn.

### Load generation: k6 Operator

k6 offers JavaScript workloads and Prometheus metrics. The k6 Operator uses Kubernetes resources to coordinate runner Jobs and divide the requested total virtual users across them.

- Locust offers Python workloads and central statistics, with master/worker integration to manage.
- JMeter offers visual test plans, with remote-engine and result-collection setup to manage.

I chose k6 Operator for its Kubernetes runner interface and fit with the shared monitoring stack. It adds a controller to maintain. Each runner evaluates [thresholds independently](https://grafana.com/docs/k6/latest/testing-guides/running-large-tests/#distributed-execution); developers assess whole-run performance in Grafana. A green workflow does not itself prove that the service meets a performance target.

## Trade-offs and limits

**Network and availability.** The demo uses one NAT Gateway and monitoring storage in one Availability Zone. This keeps the setup smaller at the cost of reduced availability.

**Cost and capacity.** Shared infrastructure keeps costing money between tests. Input bounds and fixed runner resources limit each run. The 10-node generator ceiling is shared across runs, with no guarantee of spending or load capacity.

Productpage stays at `1000m/1024Mi` while load changes; monitoring uses `t3a.medium`.

**Access and security.** GitHub OIDC provides temporary AWS credentials. Hosted runners use the public EKS API, accepting an internet-reachable control plane protected by authentication and scoped permissions.

**Cleanup and recovery.** Success, HTTP/threshold failure, active cancellation and original-UID recovery have live evidence. Timeout and other fault paths have controlled local checks where recorded. A lost GitHub Actions runner can leave resources needing manual recovery; no hard deletion deadline is promised.

**Result quality and diagnosis.** Shared Dev traffic and deployments affect measurements; these tests do not establish production capacity. HTTP 200 can hide dependency failures. The upstream Grafana dashboard has display limits: a missing-data panel is not proof of zero errors. Detailed k6 logs disappear with cleanup.

## With another week

With another week, I would work through these optional improvements:

1. **Automated whole-run evaluation.** Query Prometheus for combined latency and HTTP success across runners. Check that all expected runners have complete data before issuing a performance verdict, reported separately from execution and cleanup.

2. **AI analysis of results.** Use AI to summarize latency, throughput and error patterns from load-test data and suggest a suitable resources requests limits. Link observations to supporting metrics so developers can review recommendations before changing application or infrastructure settings.

3. **Private EKS API.** Remove public API access. Consider a GitHub self-hosted runner in the VPC, or a GitHub-hosted runner connected through a VPN such as [WireGuard](https://docs.github.com/en/actions/concepts/runners/private-networking#using-wireguard-to-create-a-network-overlay). Verify connectivity, scoped access and a separate recovery path before switching.

4. **Separate generator egress.** Give generators dedicated private subnets, route tables and a NAT Gateway to reduce competition with other private workloads for NAT capacity. Measure the benefit against added cost; internal Service DNS traffic bypasses NAT and still shares the target.

5. **Kubernetes NetworkPolicy.** Restrict generator traffic to approved destinations and required dependencies. Verify that allowed connections work and other destinations are blocked.

6. **API-side admission validation.** Enforce resource settings, workload placement and ServiceAccount rules at the Kubernetes API. Choose one policy engine, such as [OPA](https://www.openpolicyagent.org/docs/kubernetes) or Kyverno, to enforce these rules beyond workflow checks.

7. **k6 logs after cleanup.** Send logs to Loki or an existing logging service before generators are removed. Tag them by run and runner so failures can be investigated after cleanup.
