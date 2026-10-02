# Platform cluster

- [Inputs and access](#inputs-and-access)
- [Module defaults and overrides](#module-defaults-and-overrides)
- [Node placement and bounds](#node-placement-and-bounds)
- [Add-ons and storage](#add-ons-and-storage)
- [Outputs and lifecycle](#outputs-and-lifecycle)
- [Local checks](#local-checks)

This composition root creates the EKS foundation through `terraform-aws-modules/eks/aws` `21.26.0`. The local resources are the dedicated EBS CSI IAM role and its managed-policy attachment. The module owns no VPC, certificate, application, Helm release or Kubernetes provider.

Recorded Dev checks verified nodes, access, add-ons, network/storage, smoke cleanup and a no-change plan. Those runtime checks predate the generated node-group names and exact node-role names described below. A later plan against the retained cluster also reported no changes. Fresh grouped Platform deployment was not exercised and is outside the final demo scope.

The [Dev leaf](../../live/dev/ap-southeast-1/platform/cluster/terragrunt.hcl) calls this module and reads the existing VPC outputs. The module defaults retain the AMI/add-on pins and configuration verified against the Singapore AWS catalog and schemas. The [validation record](../../../docs/validation.md) owns the executed evidence; local validation alone cannot establish those AWS outcomes.

## Inputs and access

Supply an existing `vpc_id`, ordered `subnet_ids` in at least two AZs, cluster `name`, `aws_region`, and common `tags`. The Dev leaf passes the VPC private subnet list directly.

Optional `obser_subnet_id` defaults to the first entry and must belong to that list when set. The leaf omits the override.

Keep list order stable once monitoring volumes exist; changing the selected AZ affects EBS placement. `monitoring_az` is read from the selected subnet, preserving the downstream output contract.

The module uses `enable_cluster_creator_admin_permissions=true`. Upstream resolves the current provider caller to an IAM user or the source IAM role of an assumed session, then manages a `STANDARD` access entry with cluster-scoped `AmazonEKSClusterAdminPolicy`. No explicit maintainer ARN input is needed.

Use the same foundation principal for later plans and applies: changing credentials to another principal can replace this access entry. The foundation identity remains separate from the workflow identity managed by bootstrap.

Both API endpoints are enabled; the public endpoint accepts all source IPv4 addresses for the accepted GitHub-hosted runner path. IAM and EKS authorization still apply.

The leaf supplies one naming input, `name`. The cluster uses it unchanged; the control-plane role uses `<name>-eks` and the EBS role uses `<name>-ebs-csi`. Logical group keys and `workload` labels stay `main`, `obser` and `load-test`.

Under [ADR 0006](../../../docs/decisions/0006-aws-resource-naming-and-state-layout.md), [node-groups.tf](node-groups.tf) sets each node-group name base to `<name>-<group>` with `use_name_prefix=true`, so its physical AWS name includes a generated suffix.

Node roles use exact `<name>-noderole-<group>` names with `iam_role_use_name_prefix=false`. Read complete physical names from `node_group_names` or AWS inventory; do not construct them from logical keys. Exact role names remain predictable but require name-conflict checks when changed.

Inspect a fresh state-backed plan and its replacements before any future cluster apply; the recorded no-change plan applies only to its checked revision and state. Base names remain limited to 45 characters.

Only this module reads the actual account through `aws_caller_identity`; the root provider and backend retain their independently configured account allowlists.

## Module defaults and overrides

The platform maintainer owns the tested Kubernetes, node AMI and five managed add-on defaults in [variables.tf](variables.tf). `eks_managed_addons.default` contains each add-on's enable flag, exact version and JSON configuration.

The Dev leaf omits all three inputs and uses that complete bundle. No latest-version lookup is enabled. [ADR 0005](../../../docs/decisions/0005-terragrunt-iac-orchestration.md) applies the same release ownership to `platform-bootstrap` defaults.

An explicit `eks_managed_addons` map replaces the entire default. The module uses the variable directly and does not merge entries or fields with the bundle.

To remove EBS while keeping the other four add-ons, copy the four desired entries from the module default into the leaf and omit `aws-ebs-csi-driver`.

Removing an entry or setting `enabled=false` disables that add-on and its owned IAM resources. Unknown add-on names and null entries are rejected; EBS cannot stay enabled without its enabled Pod Identity Agent.

| Leaf input | Managed add-on selection |
|---|---|
| Input omitted | All five entries from the selected module revision's default |
| Explicit map with four enabled entries | Exactly those four; the omitted add-on and its owned IAM are removed |
| Explicit empty map `{}` | No add-ons; all add-on-owned resources are removed |

Each supplied entry requires an exact `version`. `enabled` defaults to `true`; optional `configuration_values` defaults to the JSON object string `"{}"`, not the module bundle's placement or storage configuration.

Copy the required JSON configuration when overriding the map. [Terraform optional attributes](https://developer.hashicorp.com/terraform/language/expressions/type-constraints#optional-object-type-attributes) also apply those attribute defaults to explicit null optional fields. No nested JSON merge occurs.

A future module-release process would validate updated defaults and runtime behavior before publishing an immutable module ref. Consumers would then select that ref and review their plan. The current demo uses the local module source.

An explicit leaf map owns all of its versions and configuration, so later module-default updates do not flow into it until the caller removes the override.

Scalar `kubernetes_version` and `node_ami_release_version` overrides remain supported. Format and AMI-minor validation do not establish regional AWS compatibility.

The Dev leaf uses the local checkout source; published platform-module releases and release automation are outside this demo. The [setup guide](../../../docs/setup.md#prepare-workflow-access) describes upgrade checks. Callers retain provider/backend configuration and account allowlists; this policy does not change provider pins.

When migrating from the earlier merge interface, remove a partial override to return to the module default, or expand it into the complete intended map before planning. A one-entry override now removes the other four add-ons.

## Node placement and bounds

| Group | Instance | Minimum / initial desired / maximum | Placement |
|---|---|---|---|
| `main` | `t3a.medium` | `1 / 1 / 2` | Both private subnets; `workload=main`; no dedicated taint |
| `obser` | `t3a.medium` | `1 / 1 / 2` | Monitoring subnet only; `workload=obser`; `dedicated=obser:NoSchedule` |
| `load-test` | `t3a.large` | `1 / 1 / 10` | Both private subnets; `workload=load-test`; `dedicated=load-test:NoSchedule` |

Dedicated workloads require both their selector and exact toleration. Bootstrap owns workload placement and the deployed Autoscaler installation.

The upstream managed-node resource ignores subsequent desired-count changes so Terraform does not reset Autoscaler capacity.

The Dev runtime inventory verified the ASG discovery tags; check them again for another deployment. Node counts and types bound compute configuration. They establish neither sustained load capacity nor a currency ceiling; traffic, storage and the retained foundation also incur costs.

Nodes use ON_DEMAND AL2023 x86-64 standard AMIs, encrypted `20Gi gp3` root disks and IMDSv2 with response hop limit `1`. No SSH access or CPU-credit override is configured.

Node roles carry worker, ECR read and IPv4 CNI policies. EBS permissions belong only to the dedicated Pod Identity role. Cluster and node operations have `60m` create/update/delete bounds.

## Add-ons and storage

The module defaults enable `vpc-cni`, `kube-proxy`, `coredns`, `eks-pod-identity-agent` and `aws-ebs-csi-driver`. The module passes only enabled entries to the public EKS module. CNI and the Pod Identity Agent select the upstream early-resource path. This does not guarantee agent readiness before nodes or EBS operations; runtime checks must establish it.

The module defaults set `nodeSelector.workload=main` for CoreDNS and the EBS controller. CNI and the Pod Identity Agent tolerate all taints; EBS node pods retain that behavior and disable the unused Windows DaemonSet. kube-proxy retains the managed defaults. Runtime checks must verify DaemonSet coverage on the dedicated groups.

Add-on operations have `30m` bounds, create conflicts fail, updates reconcile reviewed configuration, and eventual foundation removal deletes the add-ons.

`iam.tf` owns add-on-specific roles and attachments. The EBS role and attachment each use a direct enable condition with `count`; the add-on alone owns its Pod Identity association.

Disabling EBS removes all three Terraform resources, including the association nested in the add-on.

Disabling VPC CNI removes its add-on and the CNI policy attachment on each node role; shared node roles and worker/ECR policies remain. EBS cannot stay enabled with the Pod Identity Agent disabled.

Future add-on IAM belongs in `iam.tf` with its own matching enable condition.

The EBS role trusts `pods.eks.amazonaws.com` with request-tag restrictions for the cluster ARN and `kube-system/ebs-csi-controller-sa`. Its trust ARN uses the region, cluster name and caller account, without depending on EKS module outputs.

The managed EBS add-on alone owns the Pod Identity association. Its role ARN references the policy attachment's role so permissions precede association creation without delaying unrelated module data sources.

Authenticated IAM discovery and the selected add-on recommendation both confirm `arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2`. No IRSA provider or customer KMS key is created.

The module enables the EBS add-on's default StorageClass by default. Bootstrap omits PVC `storageClassName`, so new claims select the cluster default, currently `ebs-csi-default-sc`.

The output is null when EBS or its default class is disabled, and otherwise names that contract without proving runtime readiness.

Before bootstrap, inspect `gp3`, `WaitForFirstConsumer`, expansion, `Delete` reclaim policy and default annotation, then verify a temporary volume's create/mount/reuse/delete path.

## Outputs and lifecycle

Outputs provide cluster name/ARN/endpoint/base64 CA, module cluster and node security-group IDs, maps of node-role ARNs, physical group names and ASG names, monitoring AZ/subnet, add-on pins, the EBS role ARN and StorageClass name.

`cluster_security_group_id` identifies the module-managed group, which differs from AWS's primary cluster security group. `addon_versions` contains only enabled entries; `ebs_csi_role_arn` is null without the EBS role. No token or kubeconfig is exported.

Changing `name` changes the cluster and its derived resource names. Before applying current naming to an existing cluster, inspect a fresh state-backed plan for managed node-group, IAM role and child-resource replacements; a Terraform address move cannot rename those AWS resources.

Review replacement capacity and consumers before applying, then verify node/add-on readiness and cleanup. The [completed naming change](../../../docs/validation.md) owns evidence for the earlier exact-name migration; it does not validate deployment or replacement behavior of the current naming contract.

Before applying an EBS disable, remove its volume consumers and reconcile owned PVCs/EBS volumes while CSI, IAM and Pod Identity still work. The add-on flag does not delete application PVCs or data volumes. Disabling VPC CNI removes Pod networking support.

Retain the foundation on a failed apply, reconcile state and live resources, then review a fresh same-unit plan before retry.

Release owned PVC consumers and verify EBS deletion while the driver, Pod Identity Agent, role, nodes and maintainer access still work.

Full foundation destruction requires separate approval and removal of later consumers. See the [validation record](../../../docs/validation.md) for the bounded runtime checks.

## Local checks

The input-contract test runs in a temporary provider-free root containing the actual `variables.tf`, `node-groups.tf` and test file. Its synthetic IDs and versions exercise validation only.

Full-root validation must download the pinned upstream module and providers and use an isolated backend-free directory; never initialize the remote backend as part of a local check.

The naming assertions in [input-contract.tftest.hcl](tests/input-contract.tftest.hcl) check `<name>-<group>` node-group bases with prefix generation enabled, exact `<name>-noderole-<group>` IAM roles with prefix generation disabled, and stable logical keys and workload labels. These local assertions do not prove deployed names or replacement safety.

The [add-on lifecycle change](../../../docs/validation.md) records the completed IAM state migration. The [variable defaults change](../../../docs/validation.md) owns whole-map replacement and removal-plan checks.
