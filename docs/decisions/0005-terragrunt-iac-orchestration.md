# 0005: Use Terragrunt for layered Terraform infrastructure

- [Context](#context)
- [Alternatives](#alternatives)
- [Decision](#decision)
- [Consequences](#consequences)

**Status:** Accepted.

## Context

The assignment needs reusable cloud infrastructure and an explanation of how it is organized. The foundation includes account identity, DNS, networking, EKS, shared platform services and Bookinfo. These resources have different dependencies and lifetimes. Ordinary load-test runs should reuse them and manage only temporary k6 objects.

The choice was between plain Terraform, Terragrunt with Terraform, and CDKTF. The question was whether Terragrunt's shared configuration and coordination between states justified the extra setup and learning effort for this assignment.

The demo uses one Dev account in Singapore. One platform maintainer manages the foundation and Bookinfo. The layout allows separate accounts per environment and multiple regions per account, but those additional deployments have not been demonstrated.

## Alternatives

- [Infrastructure tooling](#infrastructure-tooling)
- [Where to run foundation changes](#where-to-run-foundation-changes)
- [Who manages the state backend](#who-manages-the-state-backend)

### Infrastructure tooling

| Option | Reasons to consider it | Cost for this project |
|---|---|---|
| Plain Terraform | Fewer tools; familiar plans and state; supports public modules, separate states and multiple accounts | The project must maintain provider/backend setup, output exchange and execution order across independent roots |
| Terragrunt with Terraform | Shared configuration, generated backend/provider settings, output references and a dependency-aware run queue | Another CLI and HCL configuration layer; unit paths and dependency wiring need maintenance |
| CDKTF | Programming-language types, reusable constructs and integration with Terraform modules/providers | Adds a language runtime, packages, bindings and synthesis; debugging crosses source code, generated configuration and Terraform plans |

Plain Terraform is viable for this demo. Separate state is possible with either tool. Terragrunt was selected because the current foundation already has several independently managed units that share account settings and exchange outputs. It reduces the repeated configuration and coordination code needed for those units.

CDKTF also carries an upstream maintenance risk: HashiCorp has archived the project and ended further development and compatibility updates. Its additional abstraction offers limited benefit for this setup, which mainly composes existing Terraform modules. [Official CDKTF status](https://github.com/hashicorp/terraform-cdk).

### Where to run foundation changes

- **Maintainer laptop, selected:** fits a demo managed by one person and avoids a separate privileged deployment workflow. Tool versions, credentials and execution evidence still need deliberate management.
- **Privileged GitHub Actions foundation workflow:** centralizes execution and logs, but needs an initial access setup, a foundation role, workflow protection and recovery for that initial setup.
- **AWS CloudShell:** reuses console access, with tooling, session and storage limits to manage.

The ordinary developer load workflow remains in GitHub Actions. Choosing laptop execution for foundation changes keeps those administrator credentials separate from the run identity.

### Who manages the state backend

- **Terragrunt backend creation, selected:** establishes S3 state without another Terraform unit or bootstrap state to maintain.
- **Terraform bootstrap unit with state migration:** gives Terraform ownership of the bucket, but requires moving its initial state to S3 and arranging recovery and migration back before bucket removal.
- **Terraform bootstrap unit with local state:** avoids that migration, but relies on protected local state and independent backups.

Terragrunt avoids an extra state lifecycle here. The accepted cost is that final bucket removal remains a separate task outside ordinary Terraform destruction.

## Decision

- [Layer and state boundaries](#layer-and-state-boundaries)
- [Interfaces and resource ownership](#interfaces-and-resource-ownership)
- [Public modules and version selection](#public-modules-and-version-selection)
- [Platform defaults and overrides](#platform-defaults-and-overrides)
- [Foundation execution and backend](#foundation-execution-and-backend)

### Layer and state boundaries

Use Terraform to define and change resources, with Terragrunt to share configuration and coordinate units. Assign one AWS account to each environment. Account-wide Global units sit beside the region directories; Core and Platform units belong to a region.

| Boundary | Units | Reason for the boundary |
|---|---|---|
| Global | `identity`, `dns` | Shared account identity and the delegated DNS zone can exist independently of EKS |
| Regional Core | `vpc`, `acm` | Networking and the regional certificate support downstream workloads without belonging to one application |
| Platform cluster | `cluster` | EKS, node groups and managed add-ons must exist before in-cluster services can be installed |
| Platform services | `bootstrap` | Controllers, monitoring and run access persist across application changes and load tests |
| Application pillar | `pillars/bookinfo` | The application namespace and four service releases have one owner and one application state |

These are seven leaf units with seven states. Layer folders and shared files do not create additional states. Ordinary load tests create no Terraform state.

A Bookinfo change can be planned without including network or cluster changes in that plan. Its four service modules and Helm charts remain separate inside one pillar state. Shared dependencies can still affect the application; state separation does not remove those relationships.

Shared includes hold provider/backend settings and tags. Account, environment and region context live outside reusable module code. Each unit has its own state key. Account checks and IAM enforce access boundaries; folder names alone cannot do so. The [README tree](../../README.md#infrastructure-layers) shows the layout.

Set VPC and subnet CIDRs for each deployment in [region.hcl](../../infra/live/dev/ap-southeast-1/region.hcl), while reusing the same VPC module.

### Interfaces and resource ownership

Pass small, explicit outputs between units: VPC and subnet IDs to the cluster, the delegated zone to ACM and DNS consumers, and cluster connection details to bootstrap and Bookinfo. ACM exports a validated certificate ARN. Bootstrap consumes identity, DNS, VPC, ACM and cluster references; application units consume the prepared platform.

Keep global identity independent of EKS. Cluster-specific permissions belong downstream with their consumers, avoiding a dependency from Global back to the cluster:

- The cluster unit owns cluster/node roles, the Pod Identity Agent, and EBS CSI with its role and association.
- Bootstrap owns controller-specific IAM and Pod Identity associations. It also owns the k6 integration's workflow role, EKS access entry and namespace RBAC, so these can be retired together.
- VPC CNI uses the node role as an accepted bootstrap simplification. EBS CSI and other AWS controllers use Pod Identity; IRSA is not selected. k6 Operator and Bookinfo need no AWS role solely for Kubernetes API access or internal HTTP.

DNS follows the same ownership rule. Terraform owns the delegated zone and ACM validation records; ExternalDNS owns endpoint aliases and TXT ownership records. Bookinfo and Grafana own separate Ingresses on one shared ALB. Parent NS delegation is manual. The [DNS ownership table](../architecture.md#dns-and-ingress-ownership) explains the resource boundaries.

### Public modules and version selection

Use suitable public modules directly. Keep upstream implementations upstream; add local modules under `infra/terraform-modules/` for composition, integration or a documented gap. Public-module reuse still leaves inputs, permissions and validation to this project. Check who maintains a module rather than assuming that an AWS-related module is maintained by AWS.

The version policy is:

1. Check the latest stable release in the official registry or upstream releases when planning a new slice or resuming an unimplemented plan. Recheck before finalizing the pin.
2. Review Terraform/provider constraints, upgrade notes, submodules, interfaces, defaults, permissions and state/resource-address changes. Preserve accepted constraints unless their change is explicitly agreed.
3. Pin an exact stable version or immutable reference. Provider lockfiles do not pin module source versions. Avoid floating branches or runtime selection of the latest release.
4. Record the source, subdirectory, chosen version, newest stable release observed, official release links, compatibility findings, planned checks and actual validation results. A plan or documentation review does not prove successful deployment.
5. If the newest release is incompatible, use the newest compatible stable release with the specific reason, supporting evidence and a condition for revisiting it. If official sources cannot be checked, leave freshness unverified and the affected pin pending.

A new major version needs a compatibility review; its number alone is not a reason to keep an older release. Changing a module used by deployed state requires a scoped upgrade or migration plan.

### Platform defaults and overrides

The platform maintainer owns tested version/configuration bundles in the cluster and bootstrap modules. Environment leaves normally supply their wiring and use those defaults. Bootstrap has one child module per add-on, sharing one state; Bookinfo has four service children and a shared chart library, sharing one pillar state.

The intended release model is to validate a bundle, publish an immutable module reference, and let consumers adopt it after reviewing their plans. Current Dev sources are local. Module publication, release automation and independent service-version selection are outside this demo; no separate module repository or registry is selected.

Explicit overrides transfer responsibility to the caller. Kubernetes and AMI scalar overrides stay in effect until removed. For the cluster's `eks_managed_addons` input:

| Input | Result |
|---|---|
| Omitted | Use the complete default bundle from the selected module revision |
| Explicit map | Replace the whole bundle with the supplied entries; omitted or disabled add-ons and their owned IAM resources are removed |
| Empty map `{}` | Disable all add-ons and remove their owned resources |

Each supplied entry requires an exact `version`. `enabled` defaults to `true`, and `configuration_values` defaults to the JSON string `"{}"`. Entries, fields and nested JSON are not merged with the default bundle.

The caller owns the explicit map's versions and configuration. Future bundle changes apply only after the whole map override is removed. EBS CSI requires an enabled Pod Identity Agent; storage consumers must be reconciled before disabling the driver and removing its IAM resources.

### Foundation execution and backend

The platform maintainer runs Terragrunt/Terraform from their laptop for setup, updates and final removal, using independently authenticated AWS credentials. AWS hosts the foundation and load generators. The load workflow has no ownership of foundation state or the persistent generator namespace and controls.

Terragrunt creates the S3 backend with versioning, encryption, public-access blocking and native S3 locking. The bucket identifies the environment and account; distinct keys identify each global or regional unit. This keeps shared state configuration consistent while each unit retains its own history and lock.

Backend resources sit outside the seven Terraform states. The [setup guide](../setup.md#prepare-shared-state) documents backend creation separately from the three layer applies: Global, Core and Platform. Platform orders cluster, bootstrap and Bookinfo internally; this preserves the six logical bootstrap stages and seven states.

## Consequences

- [Benefits and costs](#benefits-and-costs)
- [Failure and removal](#failure-and-removal)
- [Evidence and limits](#evidence-and-remaining-work)

### Benefits and costs

Shared includes reduce repeated provider, backend and tagging configuration. Dependency declarations show how units exchange outputs. Terragrunt's run queue orders declared dependencies for creation and reverses them for destruction, while allowing independent units to run concurrently. [Run queue behavior](https://docs.terragrunt.com/features/stacks/run-queue/).

The cost is another CLI, configuration language layer and set of dependency paths to maintain. Shared configuration changes also need review across all affected units. Terraform still owns resource planning and state; Terragrunt does not provide atomic rollback across those states.

Output references need stable contracts. Restricting a consumer to named outputs in configuration does not make those outputs a separate security boundary from the source state it can read.

### Failure and removal

Execution order does not establish readiness. EKS access must work before Kubernetes resources are managed; the Pod Identity Agent and controllers must be ready before their consumers. CRDs and their resources may still need staged installation or live checks within a unit. The [bootstrap section](../architecture.md#foundation-bootstrap) describes that boundary.

After a foundation failure, stop dependent stages and retain resources, logs, inventory and recovery state. Reconcile live resources and uncertain state writes, review a fresh plan, then retry and repeat readiness checks. Retained resources continue to cost money. Automatic rollback or destruction is not the selected recovery policy.

Ordinary run cleanup removes only that run's k6 objects and retains results, other runs, shared Dev services/data, monitoring and the foundation. Final teardown is a separate platform-maintainer action. Keep controllers, Pod Identity permissions and independent access until their dependents are removed; state recovery and monitoring-data recovery are separate responsibilities.

The [teardown order](../architecture.md#foundation-teardown) covers workflow access, ALB/DNS/certificate dependencies and storage removal. Keep state and recovery access until leftovers are reconciled. Retire the backend last, including object versions and delete markers, after preserving required evidence and recovery material elsewhere. Terragrunt's [`backend delete`](https://docs.terragrunt.com/reference/cli/commands/backend/delete/) removes state files, not the bucket infrastructure.

<a id="evidence-and-remaining-work"></a>

### Evidence and limits

The foundation and Bookinfo have scoped AWS deployment evidence, and the submission now includes their implementation. The final cluster and bootstrap plans reported no changes. Bookinfo still has one in-place Helm values update whose parsed content equals the deployment; no apply was performed for that textual difference.

The three-apply grouping has an offline dependency-ordering check. A fresh AWS deployment through that grouped path was not exercised and is outside the final demo scope. Public/internal application load, GitHub OIDC/token renewal and run cleanup have separate [workflow evidence](../validation.md#current-workflow-verification); they do not prove fresh infrastructure reproduction.

The published submission, independent Git-clone checks against retained Dev, hosted timer verification and four videos are complete and accepted. Immutable module publication and additional recovery exercises are outside the final demo scope.
