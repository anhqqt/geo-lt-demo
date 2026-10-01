# 0006: Name AWS resources by environment and region

- [Context](#context)
- [Alternatives](#alternatives)
- [Decision](#decision)
- [Consequences](#consequences)

**Status:** Accepted.

## Context

The [Terragrunt decision](0005-terragrunt-iac-orchestration.md) assigns one AWS account to each environment and separates account-wide resources from regional units. Resource names and state addresses should follow those boundaries so a platform maintainer can identify the environment, region and purpose when inspecting AWS or Terraform.

The original backend used `geocomply-load-testing-tfstate-<account_id>` with state keys starting with `dev/`. The selected layout puts the project, environment and account in the bucket name, then identifies each unit inside it. Only Dev in Singapore has been deployed; the naming rules also allow future environments and regions.

AWS services expose different identifiers. Some resources accept a configured name, some mainly use tags, and controllers generate names for their children. The convention needs clear exceptions so it does not promise names that the platform cannot control.

## Alternatives

| Option | Benefit | Cost and decision |
|---|---|---|
| Keep the original bucket and environment-prefixed keys | Keeps existing backend addresses and avoids a transition | The bucket omits the chosen project/environment prefix. Rejected in favor of one account/environment bucket with shorter unit keys |
| Adopt the selected layout and migrate existing state | Preserves state ownership when resources already exist | Requires a reviewed backend/state migration. Unnecessary for the recorded transition, because the former backend contained no Terraform state and the global resources had not been created |
| Adopt the selected layout through a scoped reset | Establishes the chosen addresses without migrating empty state | Selected after inventory and explicit approval for that demo backend. Requires retiring the old bucket and initializing the replacement; it is unsuitable as a routine procedure for populated state |

The reset choice depended on the verified starting state. It does not authorize deleting an existing deployment to make its names match this convention.

## Decision

- [Configuration and prefixes](#configuration-and-prefixes)
- [Bucket and state addresses](#bucket-and-state-addresses)
- [Configurable names and tags](#configurable-names-and-tags)
- [Service-owned identities](#service-owned-identities)
- [Adopting the layout](#adopting-the-layout)

### Configuration and prefixes

Keep each setting in one place under `infra/live/<environment>/`:

| Owner | Setting and reason |
|---|---|
| `account.hcl` | Environment, account ID and state region. The environment value must match its folder; accepted labels are `dev`, `stg` and `prod` |
| `env.hcl` | Project `geo-lt` and delegated public zone name |
| `global/dns/terragrunt.hcl` | Public hosted zone; reads its name from `env.hcl` and exposes outputs to downstream units |
| `<region>/region.hcl` | Full AWS region and a unique compact code for resource names. Singapore uses `ap-southeast-1` and `apse1` |
| `infra/live/root.hcl` | Shared provider/backend configuration and common tags |

Configure `dns_zone_name` once in `env.hcl`, following the [setup guide](../setup.md#account-and-project-settings). The DNS unit reads it through `include.root.locals.environment.dns_zone_name`; certificates and ingress hosts use the DNS outputs.

Account-global configurable names use `geo-lt-<environment>`. Regional names add the region code immediately after the environment: `geo-lt-<environment>-<region_code>`. The Dev Singapore prefix is `geo-lt-dev-apse1`; a resource purpose follows it when needed.

Compact codes leave room for purpose suffixes within service name limits. Choose each additional region's code when planning that region and keep it unique within the environment. Provider configuration and state paths retain the full AWS region identifier.

### Bucket and state addresses

Use one S3 state bucket per environment account, named `geo-lt-<environment>-<account_id>`. All regions in that account share the bucket. Its region comes from `account.hcl`, independently of the region targeted by a unit.

The bucket already identifies the environment, so state keys start below that directory:

| Unit | State key |
|---|---|
| Global identity | `global/identity/terraform.tfstate` |
| Global DNS | `global/dns/terraform.tfstate` |
| Regional VPC | `ap-southeast-1/core/vpc/terraform.tfstate` |
| Bookinfo pillar | `ap-southeast-1/platform/pillars/bookinfo/terraform.tfstate` |

The same rule gives each of the seven foundation units its own state. Full region paths distinguish regional units, while the Global keys remain shared across that account. The [architecture](../architecture.md#layers-and-state-boundaries) lists the unit boundaries.

This arrangement reduces repeated environment text in keys. It also makes unit paths part of the backend address: moving a unit folder can point Terraform at a different state key. Review state ownership before changing a bucket name or unit path. Names and tags do not enforce access; the [Terragrunt ADR](0005-terragrunt-iac-orchestration.md#foundation-execution-and-backend) covers account checks, state access and backend protection.

### Configurable names and tags

Apply common tags through shared configuration: `Project=geo-lt`, the configured `Environment`, and `ManagedBy=Terragrunt`. Add a resource-specific `Name` tag only where the owning module supports it and the convention calls for one. The backend bucket, GitHub OIDC provider and public hosted zone receive the common tags without a separate `Name` tag.

For network resources, `Name` tags make AWS-assigned IDs easier to recognize. Subnet names use the full AZ, such as `ap-southeast-1a`:

| Resource | Convention |
|---|---|
| VPC and subnets | VPC: `<regional_prefix>`; subnet: `<regional_prefix>-public-<az>` or `<regional_prefix>-private-<az>` |
| Internet gateway, NAT and Elastic IP | Append `-igw`, `-nat` and `-nat-eip`. Add AZ distinctions if the single-NAT design changes |
| Route tables | Append `-public-rt` or `-private-rt` |
| Security groups | Use `<regional_prefix>-<purpose>` where the name is configurable; inspect generated groups through supported tags and IDs |
| ACM certificate | Keep the wildcard domain and apply `Name=<regional_prefix>-wildcard`; AWS assigns the certificate ARN |

The cluster convention starts from one leaf `name`, `<regional_prefix>-main`. It keeps the current implementation: generated suffixes for physical node-group names and exact names for IAM roles.

| Resource | Derived name |
|---|---|
| Managed node group | `<cluster_name>-<group>-<generated-suffix>`, with stable logical groups `main`, `obser` and `load-test` |
| Control-plane IAM role | `<cluster_name>-eks` |
| Node IAM role | `<cluster_name>-noderole-<group>` |
| EBS CSI IAM role | `<cluster_name>-ebs-csi` |

For the Dev cluster `geo-lt-dev-apse1-main`, the main node group has a name starting with `geo-lt-dev-apse1-main-main-`. Its IAM role is exactly `geo-lt-dev-apse1-main-noderole-main`. The repeated `main` in the node-group prefix comes from the cluster identity and the logical group.

The module sets `use_name_prefix=true` for node groups. The [pinned EKS module](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v21.26.0/modules/eks-managed-node-group/main.tf#L433-L434) passes that prefix to Terraform, which generates the final suffix. Node IAM roles use `iam_role_use_name_prefix=false`.

Generated node-group names allow replacements to have distinct names, but their full names are not fixed identifiers. Use Terraform outputs or AWS inventory to find them. Scheduling keeps the stable `workload=<group>` labels; IAM roles retain predictable names.

Other IAM roles for regional components use `<regional_prefix>-<purpose>`. IAM role names are account-wide, so the region code distinguishes consumers across regions. Customer-managed policies follow the same purpose naming; AWS-managed policies keep their own names.

Validate complete names before deployment. The cluster module limits its base name to 45 characters so the longest node-role suffix fits the [64-character IAM role limit](https://docs.aws.amazon.com/IAM/latest/APIReference/API_Role.html). The shared ALB requests `<regional_prefix>` and must fit the [32-character ALB limit](https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_CreateLoadBalancer.html). Do not silently truncate names. The selected environment labels with `apse1` fit that ALB limit.

### Service-owned identities

Preserve identifiers whose meaning comes from AWS, Kubernetes or an external service:

- GitHub OIDC uses `https://token.actions.githubusercontent.com`. Route 53 uses the delegated domain and endpoint names; ACM validation records retain their issued names.
- When enabled, EKS control-plane logs use `/aws/eks/<cluster-name>/cluster`; the current module disables them. Other explicitly configurable regional log groups use the regional prefix; apply tags where supported.
- ALB target groups and other controller-created resources retain generated names. Use supported tags and resource IDs to inspect them; an exact target-group name is not part of the contract.
- Keep Kubernetes names, PVC identities and `ebs-csi-default-sc`. Dynamic EBS volumes have AWS IDs. Proposed `Name` tags ending in `-prometheus` or `-grafana` require verification through the CSI tagging path before claiming they exist.
- Generated Auto Scaling groups, instances and launch templates retain their owning module or service's identities. Inspect each resource's tags: [EKS node-group tags do not propagate automatically](https://docs.aws.amazon.com/eks/latest/userguide/create-managed-node-group.html) to associated resources.

A `Name` tag helps discovery but does not rename a resource, alter its DNS identity or prove ownership of every generated child.

### Adopting the layout

The former demo backend was inventoried and retired through an explicitly approved reset. The replacement used a clean Terragrunt download directory and fresh initialization, without `init -migrate-state`. The two Global units were applied afterward.

That record supports this one empty-backend transition. A deployment with existing state needs a separate migration or replacement plan that preserves ownership and explains the affected resources. Changing a configured AWS name can also replace resources, even when its state address stays the same.

The [setup guide](../setup.md) describes a fresh foundation setup. Ordinary k6 runs do not own these states or rename foundation resources; final foundation and backend removal remain separate maintainer tasks.

## Consequences

- [Benefits and limits](#benefits-and-limits)
- [Evidence and limits](#evidence-and-remaining-checks)

### Benefits and limits

The naming pattern makes the environment and region visible in configurable AWS names. Shared settings reduce naming drift between units, and unit-specific keys keep state ownership separate without repeating the environment in every path.

The cost is that folder names, region codes and derived names become maintained contracts. A rename may require state migration or infrastructure replacement. Adding a region also requires choosing its compact code and checking each service's limits.

One bucket per account keeps backend administration small, but all units depend on that bucket and its access controls. Separate keys provide organization; they do not by themselves restrict who can read or change state. Generated identifiers and uneven tag support still require resource-specific inspection.

<a id="evidence-and-remaining-checks"></a>

### Evidence and limits

Development records verify the replacement backend, its common tags, both Global state keys and native S3 locking. Later records cover regional resources, the cluster naming replacement and the shared ALB named `geo-lt-dev-apse1`.

The accepted convention follows the current source: generated node-group suffixes and exact node IAM role names. The final cluster plan reported no changes against existing state. Earlier naming records still describe the revisions tested then; a fresh plan remains necessary before a rename or replacement.

The submission includes implementation and selected evidence. The [validation record](../validation.md) separates current plan checks from historical deployment observations. The final bootstrap plan reported no changes; Bookinfo's remaining Helm values delta has equal parsed annotations and is not a fresh apply. These checks do not certify tags on every generated child. CSI volume `Name` tags, additional environments/regions and fresh grouped bootstrap were not verified and are outside the final demo scope.
