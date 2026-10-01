# 0007: Bootstrap addon modules

- [Context](#context)
- [Alternatives](#alternatives)
- [Decision](#decision)
- [Consequences](#consequences)

**Status:** Accepted.

## Context

EKS needs controllers, monitoring and generator access before load testing. Each addon needs a clear configuration and permission owner, while sharing one bootstrap lifecycle and state.

Grafana and Bookinfo also need DNS records once their Ingresses have an ALB address. The hosted zone and certificate already have Terraform owners. This decision refines bootstrap packaging in [ADR 0005](0005-terragrunt-iac-orchestration.md) and endpoint ownership in [ADR 0004](0004-github-actions-self-service-workflow.md); their other decisions remain unchanged.

## Alternatives

| Option | Benefit | Trade-off and choice |
|---|---|---|
| Shared chart wrapper | Centralizes Helm wiring | Adds a common interface over chart-specific configuration and permissions; rejected |
| **One child per addon** | Keeps each chart, its values and permissions together | Repeats Helm wiring; selected for clear ownership within one state |
| Terraform endpoint records | Keeps record changes in Terraform plans | Requires ALB address lookup and record management separate from Ingresses; earlier design |
| **ExternalDNS** | Reconciles records from trusted Ingress hostnames and ALB status | Adds a controller, permissions and asynchronous cleanup; selected to follow Ingress configuration |

## Decision

- [Module and access boundaries](#module-and-access-boundaries)
- [Defaults and overrides](#defaults-and-overrides)
- [Ingress and DNS ownership](#ingress-and-dns-ownership)
- [Monitoring and storage](#monitoring-and-storage)
- [Disable and teardown](#disable-and-teardown)

### Module and access boundaries

Use `infra/terraform-modules/platform-bootstrap` with one child under `modules/<addon>/` per public chart. Each child declares a direct `helm_release`. All share the regional `platform/bootstrap` state, preserving the [seven-unit layout](../architecture.md#layers-and-state-boundaries).

Dev enables ALB Controller, Cluster Autoscaler, ExternalDNS, Metrics Server, k6 Operator and kube-prometheus-stack.

| Child file | Responsibility |
|---|---|
| `main.tf` | Release and dependencies |
| `values.override.yaml` | Chart configuration rendered through `templatefile(...)` |
| `iam.tf`, when needed | IAM and Pod Identity resources |
| Variables and related files | Settings and resources owned by that addon |

Each enable flag controls installation and owned access resources. A separate object supplies configuration, such as `enable_external_dns` / `external_dns`. Add and check future addons individually using this pattern.

Access follows three boundaries:

- **AWS controllers:** dedicated Pod Identity roles. The ALB release and association share a namespace and ServiceAccount `alb-controller`; role/policy names derive from `cluster_name`. Use the public module's default trust without extra conditions. Metrics Server needs no AWS identity.
- **k6 Operator:** Helm-created namespace and chart-managed cluster RBAC (`rbac.namespaced=false`). Watching one runner namespace does not narrow those permissions.
- **Workflow and runners:** namespace-scoped workflow RBAC. Bootstrap creates the runner namespace when separate; Pods use its `default` ServiceAccount without added API grants. See [workflow access](0004-github-actions-self-service-workflow.md#workflow-access).

Do not add a shared `addons_override` map, `bootstrap_step`, `terraform_data.contract`, or ALB/Ingress lookup framework.

### Defaults and overrides

The platform maintainer owns tested defaults; leaves supply deployment wiring and differences. The [release policy](0005-terragrunt-iac-orchestration.md#platform-defaults-and-overrides) targets immutable module releases. Current sources remain local.

Configuration flows in this order:

1. Root objects use `default = {}` and `nullable = false`, with direct field access and no `try`. Omitted release fields pass null to child defaults with `nullable = false`.
2. Children define typed Helm options, including `upgrade_install=true` with false overrides, and render `values.override.yaml` through `templatefile(...)`.
3. `context` and `context_sensitive` apply afterward. Validation protects reserved controller and identity settings.

The Dev leaf uses release defaults, supplying zone settings under `external_dns`, GitHub identity under `k6_operator`, and Grafana exposure under `kube_prometheus_stack`.

Use chart-default images except for Autoscaler, whose template pins an image matching the EKS minor version. Check chart, image and provider compatibility together.

### Ingress and DNS ownership

The monitoring module depends on ALB Controller and ExternalDNS. Terraform orders installation; the [validation record](../validation.md) separately records controller readiness, healthy ALB targets and DNS reconciliation for the demonstrated deployment.

| Owner | Resources |
|---|---|
| `global/dns` | Public hosted zone and delegation outputs; the platform maintainer adds parent NS records |
| `core/acm` | Regional wildcard certificate, validation CNAMEs and issuance wait |
| Monitoring and Bookinfo | Their Ingresses, hostnames and certificate references |
| ALB Controller | Generated ALB resources and address in Ingress status |
| ExternalDNS | Endpoint aliases and TXT ownership records |

**Grafana exposure** uses the chart-owned Service and Ingress, without duplicate Terraform resources:

- `grafana_ingress_enable` defaults off; Dev enables it and sets `grafana_ingress_host` and `grafana_ingress_annotations`.
- The leaf takes ALB name/group, public subnets and validated certificate from existing dependencies; it omits `group.order`.
- Caller annotations override child ALB defaults. The root derives the tags annotation from nonempty `var.tags`; explicit tags override it. Bookinfo uses the same convention, so shared tags must agree. Bootstrap owns common ALB configuration.

**ExternalDNS** keeps endpoint records separate from the zone and certificate:

- Discover trusted Ingress rule hostnames and ALB status. Use `external_dns.dns_zone_id`, `external_dns.dns_zone_name`, public-zone and `alb` class filters. No hostname annotation filter or Grafana hostname/source annotations are needed.
- Keep `sync`, the [TXT registry](https://kubernetes-sigs.github.io/external-dns/latest/docs/registry/txt/), cluster-name owner ID and record-type prefix module-owned. Keep owner/prefix stable while records exist; protect filters, ownership and single-writer settings from generic overrides.
- Use its own Pod Identity role/association. IAM limits mutations to the delegated zone; listing is broader. TXT ownership protects individual records through controller behavior, beyond that zone-level IAM boundary.
- Preserve NS/SOA, ACM validation and unrelated records. Do not create duplicate Terraform endpoint records or add Cloudflare credentials/providers.

The selected ALB, hostnames and certificate stay unchanged. See [DNS ownership](../architecture.md#dns-and-ingress-ownership) for their place in the foundation.

### Monitoring and storage

| Area | Decision |
|---|---|
| Components | Prometheus, Grafana and Prometheus Operator on the monitoring node group with bounded resources; disable extra exporters, Alertmanager and default Kubernetes monitoring |
| Grafana | Chart-configured datasource; HTTPS root URL and secure cookies when publicly exposed |
| Storage | PVCs omit `storageClassName`. The cluster owns EBS CSI, its Pod Identity role and default StorageClass; bootstrap owns monitoring |

The [storage design](../architecture.md#monitoring-storage) retains the single-AZ availability limit. Ordinary run cleanup preserves monitoring, PVCs and results.

### Disable and teardown

**Ingress disable and addon removal have different effects:**

| Action | Effect |
|---|---|
| Disable Grafana ingress | Preserves the monitoring release and data |
| Disable monitoring | Removes the release. Source inspection indicates Grafana PVC/administrator Secret removal; Prometheus PVCs and the Helm-created namespace may remain. Live uninstall is unverified |
| Disable k6 integration | Removes workflow IAM, EKS access and RBAC, plus a separately managed runner namespace. Helm uninstall alone leaves Terraform-managed access |

Keep cleanup dependencies available:

1. Stop active runs and verify cleanup before removing the k6 integration and its access resources together.
2. Remove Bookinfo/Grafana exposure through their owners. Keep EKS, ALB Controller, ExternalDNS and permissions until aliases/TXT records and ALB rules/targets are gone. Verify ALB/listener removal after the last Ingress consumer; other consumers retain the shared ALB.
3. Retain required monitoring data before uninstall. Reconcile PVCs/volumes while EBS CSI and its permissions work. A leftover Helm-created namespace is acceptable, but inspect its contents.
4. Remove ACM validation through `core/acm` only after the certificate is unused. Follow the remaining [foundation teardown](../architecture.md#foundation-teardown).

Disabling a controller does not prove its resources are gone. Ordinary run cleanup preserves this foundation, including DNS and certificates.

## Consequences

- [Trade-offs](#trade-offs)
- [Evidence and limits](#evidence-and-remaining-checks)

### Trade-offs

| Choice | Accepted cost |
|---|---|
| Separate addon modules | Repeated Helm wiring keeps chart-specific behavior visible |
| One bootstrap state | Fewer units; plans must cover combined addon effects |
| Controller-owned DNS | No application Terraform record duplication; readiness and removal require live checks, including preservation of unrelated records |
| Defaults with overrides | Shared changes can affect other consumers. Upgrades need source review, focused checks, deployment evidence and human acceptance |

<a id="evidence-and-remaining-checks"></a>

### Evidence and limits

Development verification covers:

- **Platform:** six addon installations, controller-role activity, bounded Autoscaler scale-up/down, Metrics API and k6 lifecycle smoke.
- **Endpoints:** earlier annotation-based ALB/DNS/TXT creation/removal preserved delegation and ACM records. Later Grafana/Bookinfo checks prove rule-host publication, public HTTPS and shared ALB coexistence. Bookinfo exposure recovery is user-confirmed without an agent-executed trace.
- **Monitoring:** distinct runner remote-write series and Pod-recreation persistence, followed by real Bookinfo load. Upstream dashboard revision 8 was applied and checked through Viewer live/post-cleanup access; a fresh bootstrap plan reported no changes.
- **Workflow:** genuine GitHub OIDC/token renewal, public/internal runs, rejected inputs, cancellation, peer preservation and original-UID recovery. The [validation record](../validation.md#current-workflow-verification) distinguishes AWS results from local fault tests.

These observations cover tested operations. The no-change bootstrap plan resolves the earlier source/deployment difference around Grafana `group.order`. The final Bookinfo plan retains a textual Helm values change with equal parsed annotations; it was not applied.

Live Grafana exposure removal, addon/workflow-access removal and residual PVC cleanup were not exercised and are outside the final demo scope. Publication, independent Git-clone checks against retained Dev, hosted timer verification and four videos are complete and accepted.

The [selected Helm provider](https://github.com/hashicorp/terraform-provider-helm/blob/v3.3.0/go.mod) embeds an SDK whose [published support range](https://helm.sh/docs/v3/topics/version_skew/) excludes EKS 1.36. Successful releases establish only the tested operations.

This submission includes implementation and selected evidence. Detailed development records retain their original scopes; [setup](../setup.md) records the execution path and its verification limits.
