# 0002: Use EKS as the execution platform

- [Context](#context)
- [Alternatives](#alternatives)
- [Decision](#decision)
- [Consequences](#consequences)

**Status:** Accepted

## Context

The load workflow needs somewhere to run generators against a prepared Dev service. Before comparing platforms, the project had already chosen AWS, Terraform, Bookinfo, separate application and generator hosts, and both internal and public target routes.

The foundation and four Bookinfo services have recorded AWS creation evidence. Ordinary tests reuse that deployment and create only temporary generator resources. Repeating blank-account setup and final removal of the foundation are outside the completed demo.

The platform choice was EKS, ECS on EC2, or EC2 with Docker Compose. Each could support the demo. The decision concerns workload management, access controls and maintenance effort, rather than a measured performance difference between platforms.

## Alternatives

- [Execution platform](#execution-platform)
- [Controller placement](#controller-placement)
- [Outbound networking](#outbound-networking)

### Execution platform

| Option | How it would fit | Main trade-off |
|---|---|---|
| **EKS, selected** | Kubernetes Services for internal discovery, ALB integration, separate managed node groups, and API permissions for run objects | Portable workload manifests and Kubernetes controls, with cluster add-ons, IAM integration and scheduling to maintain |
| **ECS on EC2** | Separate application/generator Auto Scaling groups through capacity providers, Cloud Map discovery and an ALB; a generator task per run | Managed scheduling and AWS integration, with AWS-specific task definitions and workflow logic for limits and cleanup |
| **EC2 with Docker Compose** | An application VM and a separate generator VM; private DNS and an ALB for the target | Fewer orchestration components and direct host debugging, with more custom host setup, health checks, recovery and run isolation |

EKS was selected for Kubernetes workload portability and scoped API permissions. It also leaves a path to GitOps with Argo CD. These benefits were considered worth the additional platform work; GitOps and multi-cloud deployment remain outside the demo.

Portability applies to workloads on compatible Kubernetes clusters. ALB, IAM, DNS and storage integrations still need cloud-specific changes. ECS remains a viable AWS-focused alternative; its [EC2 capacity providers](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/asg-capacity-providers.html) can also separate compute pools.

### Controller placement

The AWS Load Balancer Controller and k6 Operator need a home outside the generator workers. Three arrangements were considered:

- **Both on `main`, selected:** one placement policy, while `obser` stays focused on monitoring. Controllers share application CPU and memory.
- **Both on `obser`:** separates them from Bookinfo, but makes them share monitoring capacity and its single-AZ availability limit.
- **ALB Controller on `main`, k6 Operator on `obser`:** splits the controller load, with two placement policies and the same monitoring-side dependency for k6 orchestration.

The selected placement needs explicit requests/limits and enough capacity for Bookinfo plus controllers. It does not give either controller a dedicated host.

### Outbound networking

| Option | Benefit | Accepted cost or reason to defer |
|---|---|---|
| **Private nodes with one shared NAT Gateway, selected** | No public node IPs; fewer NAT resources to operate | Shared outbound capacity and dependence on one NAT Gateway's AZ |
| **Private nodes with a NAT Gateway per AZ** | Each AZ has its own outbound path | More NAT resources and ongoing cost |
| **Public-subnet nodes with public IPv4 and no NAT** | Removes NAT resources from the outbound path | Changes node exposure and requires a separate access-control assessment |

One NAT Gateway keeps the demo smaller. If its AZ fails, private workloads in the other AZ also lose that outbound internet path. [AWS NAT availability guidance](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-basics.html) explains this trade-off.

Dedicated generator subnets, routes and NAT are a separate future improvement for reducing outbound contention. That separation would not remove combined load on Bookinfo or all shared-network effects. No NAT bottleneck has been measured.

## Decision

- [One cluster, separate compute groups](#one-cluster-separate-compute-groups)
- [Persistent foundation and temporary runs](#persistent-foundation-and-temporary-runs)
- [Network routes and API access](#network-routes-and-api-access)
- [Bounded capacity](#bounded-capacity)
- [Monitoring and storage](#monitoring-and-storage)

### One cluster, separate compute groups

Use one EKS cluster in Singapore (`ap-southeast-1`) with three EKS managed node groups. The design uses managed node groups, not Karpenter NodePools.

| Group | Intended workloads | Reason for separation |
|---|---|---|
| `main` | Bookinfo, platform controllers and general workloads | Keeps application hosts separate from load generators |
| `obser` | Prometheus and Grafana | Gives monitoring separate compute and an explicit storage/AZ policy |
| `load-test` | k6 initializer, starter and runner Pods | Lets generator capacity grow without placing generators on application hosts |

Node selectors choose the intended group. Taints and tolerations restrict placement on dedicated groups. Run templates must apply these settings to helper Pods as well as runners; naming a group alone does not enforce placement. System components can still use capacity on these nodes. `main` and `load-test` can use either private subnet; one initial node does not mean a node in each AZ.

The current module pins EKS `1.36` with a selected AMI and managed add-on bundle. Updates require compatibility checks and deployment validation. [ADR 0005](0005-terragrunt-iac-orchestration.md#platform-defaults-and-overrides) owns version/default policy and caller overrides; this ADR selects the platform and compute boundaries.

### Persistent foundation and temporary runs

The platform maintainer prepares the target and real dependencies before a test. Bookinfo uses `productpage`, `details`, `review` and `ratings`; `review` runs the upstream `reviews-v2` application. This setup needs no external database or Istio components.

The demo workload repeats `GET /productpage`, checking only `status === 200`. That assertion can miss a failed dependency behind a successful page response. The [request paths](../architecture.md#send-traffic) describe which services the test exercises.

Bootstrap owns one persistent generator namespace, its ServiceAccount and RBAC. Each run creates its own TestRun, script ConfigMap and associated helper/runner objects. It must remove those objects after success, failure, cancellation or timeout, preserving other runs and the namespace controls.

Run cleanup also preserves Bookinfo and its dependencies, all node groups, ALB/DNS/certificates, monitoring and retained results. Foundation deployment and final teardown belong to the platform maintainer. [ADR 0005](0005-terragrunt-iac-orchestration.md#layer-and-state-boundaries) defines the separate cluster, bootstrap and application owners.

### Network routes and API access

Use an IPv4 VPC with two public and two private subnets across two AZs. Worker nodes have no public IPs. The internet-facing ALB uses both public subnets; private nodes use the shared NAT Gateway for outbound internet traffic.

Choose the VPC and subnet CIDRs in [region.hcl](../../infra/live/dev/ap-southeast-1/region.hcl) to suit the AWS environment where you deploy.

The supplied URL determines the network path. Both HTTP and HTTPS are accepted; these Bookinfo examples exercise different paths:

- **Internal:** supply a complete HTTP or HTTPS URL. The Bookinfo default is `http://productpage.bookinfo.svc.cluster.local/productpage`; its Service DNS route bypasses the public ALB and NAT.
- **Public:** the Bookinfo HTTPS URL sends traffic through the shared NAT to the internet-facing ALB and delegated domain. Target URLs have syntax checks but no destination allowlist; the developer must have permission to test the target.

Bookinfo and Grafana use separate host rules on one ALB, with the same regional wildcard certificate. They share frontend capacity and configuration. The [DNS ownership table](../architecture.md#dns-and-ingress-ownership) separates zone, certificate, Ingress and endpoint-record ownership; parent NS delegation remains manual.

EKS has public and private API endpoints. The GitHub-hosted runner uses the public endpoint to orchestrate tests; k6 traffic originates inside EKS. This avoids adding a private runner connection for the demo, while accepting an internet-reachable API protected by authentication and permissions.

Platform maintainer, workflow, controller and runner identities remain separate. Kubernetes RBAC limits available actions, but cannot enforce object ownership between runs in one namespace or validate arbitrary TestRun/Pod fields. Trusted templates must enforce placement, bounds and cleanup selection. The k6 Operator's watch namespace does not reduce its broader chart permissions. See [access and operating limits](../architecture.md#5-access-and-operating-limits).

### Bounded capacity

Cluster Autoscaler adjusts node capacity for eligible unschedulable Pods within each group's limits. All three groups start with one node and have a minimum of one. `main` and `obser` each allow two nodes; `load-test` allows ten, shared across all runs. Initial desired counts are not fixed runtime counts.

These are demo starting sizes: `main` and `obser` use `t3a.medium`; `load-test` uses `t3a.large`. Workload fit includes application, controller, helper and system overhead. The [compute table](../architecture.md#compute-and-scaling) records the configuration together with its limits.

The run template gives each k6 runner requests of 500m CPU / 512 MiB and limits of 1 CPU / 1 GiB. Initializer and starter resources are also fixed in the template. Per-run inputs are bounded, but no global concurrent-run or total-VU cap is selected. Runs whose runners cannot become ready must stop and clean up after the 15-minute startup deadline.

Node ceilings limit one part of resource use. They do not guarantee load capacity or cap the AWS bill. The T3a nodes inherit the account's CPU-credit default without an IaC override; sustained-load capacity remains unmeasured. NAT/ALB traffic, storage and the persistent foundation also incur costs between tests.

### Monitoring and storage

Prometheus and Grafana run on `obser`, restricted to one existing private subnet. Keeping replacement nodes in the volumes' AZ allows retained EBS volumes to be reattached without adding more node groups. This accepts monitoring downtime during replacement and unavailability during an AZ outage. [AWS's managed-node guidance](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) explains the EBS/AZ constraint.

Prometheus and Grafana use separate gp3 volumes. EBS CSI and its Pod Identity role belong to the cluster unit and must be ready before bootstrap creates monitoring storage. Run cleanup preserves the PVCs and their data.

The default StorageClass delays volume creation until scheduling and uses reclaim policy `Delete`. Removing a PVC can therefore remove its volume. Final foundation teardown needs a separate data-retention decision and ends access to in-cluster results. The [storage section](../architecture.md#monitoring-storage) records sizes and recovery limits.

## Consequences

- [Benefits and operating cost](#benefits-and-operating-cost)
- [Isolation and availability limits](#isolation-and-availability-limits)
- [Evidence and limits](#evidence-and-remaining-work)

### Benefits and operating cost

EKS gives the workflow a Kubernetes API for run resources, Services for internal discovery and scheduling controls for separate generator hosts. The same platform supports Bookinfo, k6 orchestration and shared monitoring.

The cost is cluster and add-on maintenance, IAM integration, version compatibility, scheduling and lifecycle checks. The platform maintainer must also account for idle foundation cost. EKS does not by itself supply a safe self-service workflow or prove correct cleanup.

### Isolation and availability limits

- **Compute separation:** avoids generators sharing Bookinfo hosts, but the cluster, network, target and some platform services remain shared. Other Dev deployments and traffic can change measurements.
- **Availability:** two AZs provide subnet choices, but initial single-node groups, one NAT and single-AZ monitoring do not establish high availability.
- **Access boundaries:** the fixed namespace is intended for trusted automation. Stronger admission validation and generator NetworkPolicy remain future work.

Private API access, dedicated generator egress and policy enforcement are described in the [writeup's next-week priorities](../../WRITEUP.md#with-another-week). Per-AZ NAT, Argo CD and multi-cloud remain alternatives, not requirements for finishing this demo.

<a id="evidence-and-remaining-work"></a>

### Evidence and limits

Development records establish these checks within their recorded scopes:

- **Cluster:** node readiness, network and placement probes, EBS provisioning and retained-PVC reuse.
- **Bootstrap:** controller and permission checks, Autoscaler scaling from one to two nodes and back with inert test Pods, and monitoring persistence after Pod recreation.
- **Bookinfo:** internal/public endpoint checks and real dependency calls, followed by published workflow load on both routes.
- **Workflow:** genuine GitHub OIDC access and token renewal, rejected inputs, native runner outcomes, retained results and UID-scoped cleanup. Active cancellation preserved a concurrent run; original-UID recovery removed force-cancel leftovers and passed a repeat recovery.

The [validation record](../validation.md#current-workflow-verification) separates these AWS observations from local timeout and fault tests. Basic live and post-cleanup dashboard checks passed with a Viewer account on upstream revision 8. Short load samples do not prove ten-node capacity, sustained sizing, node/AZ recovery or every platform operation.

The final cluster and bootstrap plans reported no changes. Bookinfo has an in-place Helm values difference with equal parsed content, so its final plan is not a no-change result. Publication, independent Git-clone checks against retained Dev, hosted timer verification and four videos are complete and accepted. A fresh grouped deployment and additional fault cases were not exercised and are outside the final scope. The [setup guide](../setup.md) records the execution path and its limits.
