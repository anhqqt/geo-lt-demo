# 0008: Bookinfo service modules and shared Helm library

- [Context](#context)
- [Alternatives](#alternatives)
- [Decision](#decision)
- [Consequences](#consequences)

**Status:** Accepted.

## Context

Bookinfo needs four separately configurable services with similar Kubernetes manifests. Each service needs its own image, application settings and resource defaults. Shared templates can keep their workload structure consistent.

The [bootstrap addon pattern](0007-bootstrap-addon-modules.md) already gives each child module explicit chart settings and Helm options. Apply that pattern to Bookinfo while keeping one pillar module, one Terragrunt unit and one state, as selected in [ADR 0005](0005-terragrunt-iac-orchestration.md). The prepared-target lifecycle in [ADR 0001](0001-existing-dev-services-and-dependencies.md) remains unchanged.

## Alternatives

| Option | Benefit | Trade-off and choice |
|---|---|---|
| Native Terraform Deployments and Services | Shows individual Kubernetes resources in the plan | Does not provide the selected shared-chart and per-service Helm interface; rejected |
| One umbrella Helm release | Can share templates and deploy the application together | Combines all four release lifecycles; rejected for this service-module design |
| **Separate service releases with a library chart** | Gives each service its own configuration and release while sharing templates | Adds chart packaging and version coordination; selected within one pillar state |

The selected approach keeps service changes explicit without adding a Terraform state for every service. It repeats some release wiring, and a library change still needs checks across all consumers.

## Decision

- [Modules, charts and ownership](#modules-charts-and-ownership)
- [Defaults and deployment overrides](#defaults-and-deployment-overrides)
- [Versions and dependency builds](#versions-and-dependency-builds)
- [Exposure and removal](#exposure-and-removal)

### Modules, charts and ownership

Use `infra/terraform-modules/bookinfo/` with four service children: `ratings`, `details`, `review` and `productpage`. Each declares `helm_release.this`. The local `review` name uses the upstream reviews-v2 application, as explained in [ADR 0001](0001-existing-dev-services-and-dependencies.md).

| Owner | Responsibility |
|---|---|
| Bookinfo root | Shared namespace, explicit child calls and an enable/configuration pair per service |
| `modules/<service>/` | Release settings, typed Helm options and deployment overrides |
| `charts/<service>/` | Application chart, complete defaults and local `file://../libchart` dependency |
| `charts/libchart/` | Shared named templates; no release of its own |
| Helm | Deployments, Services, optional productpage Ingress and release metadata in Kubernetes Secrets |

All Terraform resources share `platform/pillars/bookinfo` state. A child inherits the root namespace; a namespace override must match it. No separate service state, application IAM, database, cache, queue or Istio is introduced.

### Defaults and deployment overrides

Each child follows bootstrap's interface: `release_name`, `namespace`, `repository`, `chart_name`, `chart_version`, `context`, `context_sensitive` and typed `helm_options`. Child defaults select the bundled chart at `${path.module}/../../charts/<service>` and the release lifecycle. All four default `upgrade_install` to true and accept an explicit false override.

Values apply in this order:

1. **Chart defaults:** `charts/<service>/values.yaml` exposes supported image, environment, resources, probes, placement and security settings. The library supplies templates without hidden imported defaults.
2. **Deployment overrides:** Terraform renders only the child's `values.override.yaml` through `templatefile`. Ratings, details and review start with an empty map; productpage supplies Ingress settings and annotation defaults.
3. **Helm set overrides:** `context` and `context_sensitive` take precedence. The platform maintainer owns compatibility checks for these overrides and replacement charts.

Keep Terraform directives outside chart files. Helm loads the selected chart's defaults itself, so charts can render and be packaged independently. Selecting an external chart must not read defaults from the bundled chart.

Resource limits are optional: missing or null CPU/memory limits are omitted, including an empty limits map. Explicit limits pass through without custom limits validation. The library retains positive CPU/memory request checks and immutable-image checks; valid rendering does not prove adequate runtime capacity.

### Versions and dependency builds

The normal Dev leaf enables all services through defaults and supplies environment wiring without image inputs. Images and workload defaults belong to service chart releases.

| Change | Required handling |
|---|---|
| Deployment override | Changes that service's Terraform values input |
| Chart default or template | Bump the chart version and matching Terraform `chart_version` |
| Shared library | Bump its version, update consumer dependencies/locks and bump affected application chart versions; render all consumers |

A local chart edit at the same version can leave Terraform reporting no changes. Explicit versions carry the release change; do not add source hashes to release descriptions.

Local dependency handling follows these rules:

- Rebuild each service's library dependency before planning or applying, including after a library edit. Dependency resolution alone does not prove an existing archive is current.
- Run Terragrunt's build hooks inside its downloaded module. Keep chart source and locks versioned; ignore generated dependency archives.
- Before applying, inspect rendered manifests as well as the Terraform plan. The plan shows release changes and may not validate templates when Helm lint is disabled.

Service modules and the Dev pillar use local sources. Independent version selection, publication and release automation are outside the final demo. A future release could carry each service's chart and image defaults under an immutable module version.

Charts may later move to a dedicated repository. That would require immutable packages containing their library dependency, compatible repository/chart/version selections, and replacement or removal of the local build hooks. No external chart repository is selected by this decision.

### Exposure and removal

Productpage's configuration adds `ingress_enable`, `ingress_host` and `ingress_annotations`, with child-owned defaults. Dev enables exposure and supplies the shared ALB, subnet and certificate settings through dependency outputs. Caller annotations override child defaults; root tags supply the ALB tags annotation unless explicitly overridden.

Bookinfo shares Grafana's ALB, certificate and ExternalDNS contract. Shared annotations and tags must agree across both owners. The chart owns its Ingress; controllers manage the generated ALB resources and endpoint records. [ADR 0007](0007-bootstrap-addon-modules.md#ingress-and-dns-ownership) explains those boundaries.

| Action | Scope |
|---|---|
| Disable productpage ingress | Removes public exposure while preserving application Deployments and Services |
| Disable a service | Removes its release and chart resources; preserves the shared namespace and other releases, but may break their dependency path |
| Remove the pillar | Removes its namespace and releases; requires separate foundation-lifecycle review |
| Clean up a load run | Preserves Bookinfo and the shared foundation |

Keep ALB Controller and ExternalDNS available until endpoint removal finishes. Verify that Grafana and other ALB consumers survive Bookinfo exposure changes. The required order is covered in [foundation teardown](../architecture.md#foundation-teardown).

## Consequences

- [Trade-offs](#trade-offs)
- [Evidence and limits](#evidence-and-remaining-checks)

### Trade-offs

- Separate releases make service changes easier to inspect, but all still share one Terraform state and application dependencies.
- The library reduces repeated manifests. A template change can affect every consumer, so checks must cover the full application.
- Chart-owned defaults support standalone packaging. Maintainers must keep chart versions, dependency locks and module defaults consistent.
- Explicit chart/context overrides add flexibility and compatibility responsibility. Sensitive inputs may persist in Terraform state and Helm release Secrets, even when normal output redacts them.

<a id="evidence-and-remaining-checks"></a>

### Evidence and limits

| Evidence | What it establishes |
|---|---|
| Recorded Dev deployment | Four Ready services, real dependency calls, public/internal routes and shared ALB/DNS/TLS checks, with Grafana preserved |
| Exposure removal/restoration | User-confirmed recovery; no agent-executed lifecycle trace is claimed |
| Local chart checks | Complete defaults, standalone/package rendering, optional limits, override/version tracking, sibling preservation, context precedence and chart relocation |
| Published application load | Public/internal Bookinfo runs at the current Productpage baseline, native runner outcomes, retained results and verified cleanup |

Productpage's chart and deployed baseline use 1000m CPU and 1024Mi memory for requests and limits. Short load samples include passing and failing latency outcomes; they do not establish sustained application capacity. The [validation record](../validation.md#current-workflow-verification) retains each tested baseline and outcome.

The final Bookinfo plan proposes one in-place Helm values change. Old and proposed values parse to equal objects, including the Ingress annotations; no apply was performed for this textual difference. This is scoped source/deployment reconciliation, not proof of fresh grouped bootstrap or every chart override on AWS.

The published submission includes implementation, selected evidence and four videos, with independent Git-clone checks and human acceptance. Full-pillar destruction was not run and is outside the final demo scope. [Setup](../setup.md) describes the execution path and its limits.
