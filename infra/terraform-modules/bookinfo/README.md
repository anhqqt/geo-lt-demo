# Bookinfo pillar

- [Configuration](#configuration)
- [Ratings behavior](#ratings-behavior)
- [Details behavior](#details-behavior)
- [Review behavior](#review-behavior)
- [Productpage behavior](#productpage-behavior)
- [Productpage Ingress](#productpage-ingress)
- [Local verification and chart dependencies](#local-verification-and-chart-dependencies)
- [Ownership and recovery](#ownership-and-recovery)

One Terraform root owns the shared namespace and composes one child module per service. Each child deploys its own Helm chart through `helm_release`; those charts reuse templates from `libchart` and expose their own complete defaults. All children share the pillar's Terraform state.

Bookinfo has recorded readiness, request-path and load checks. Each result applies to its recorded deployment snapshot. The current library permits missing or null limits, omits null entries from manifests and retains request/image validation.

Later maintainer deployment, resource readback and workflow runs are recorded in the [current verification](../../../docs/validation.md#current-workflow-verification); the earlier no-change plan and readiness evidence retain their original scope.

The recorded Dev deployment had all four services and productpage exposure. The platform maintainer deployed the full pillar before verification. Four 1/1 Ready services on `main` had the exact chart-owned image digests, resources and security settings for that snapshot.

Real dependency calls, internal HTTP and public HTTPS from a dedicated `load-test` node, shared-ALB target health, DNS/TLS, redirect and Grafana preservation passed. The temporary probe was deleted and verified absent. Checks more than ten minutes apart found unchanged Pod identities, zero restarts and no new startup warnings.

The verified deployment snapshot had a no-change Bookinfo plan. Later source and live load checks have their own recorded scopes in [validation](../../../docs/validation.md). Future values/template or chart-version changes require a fresh maintainer plan and the affected runtime checks.

The latest source comparison found an in-place Productpage Helm-values difference in quoting and key order; the old and proposed values parsed to equal YAML objects. It was not applied or reported as a no-change plan.

Ordinary load runs reuse this prepared application. The active leaf is `platform/pillars/bookinfo`, and its state owns the namespace plus four Helm releases.

The recorded inspection found the former `platform/services/bookinfo` state empty with a different lineage; it does not prove migration history or a predeployment baseline.

Public/internal application load and scoped cleanup have recorded workflow evidence; sustained sizing remains unverified. The platform maintainer confirmed exposure removal/restoration; the [validation record](../../../docs/validation.md) records it as user-verified, without claiming agent-executed lifecycle evidence. Full-pillar destruction was not run and is outside the final demo scope.

An earlier inventory found the `main` node using all 17 Pod slots, with requests of `1350m/1930m` CPU and `2168Mi/3306Mi` memory. This is a historical snapshot, not a current capacity reading. Additional Pods may require Cluster Autoscaler to add the group's second node within its configured maximum of two.

```text
bookinfo/
  main.tf                         # Shared namespace and service module calls
  variables.tf                    # Provider inputs and service configuration objects
  providers.tf                    # Renewable AWS CLI exec authentication
  charts/
    libchart/
      Chart.yaml                  # type: library
      values.yaml                 # Empty; service charts own their defaults
      templates/                  # Shared Deployment, Service and Ingress templates
    <ratings|details|review|productpage>/
      Chart.yaml                  # file://../libchart dependency
      Chart.lock
      values.yaml                 # Complete defaults for this service
      templates/app.yaml          # Calls the library templates
  modules/
    <ratings|details|review|productpage>/
      main.tf                     # helm_release.this selects ../../charts/<service>
      variables.tf                # Release settings and Helm operation defaults
      outputs.tf                  # Configured Service reference
      versions.tf
      values.override.yaml        # Deployment overrides; productpage supplies Ingress
```

No application is installed by the library itself. [Source selection](../../../docs/validation.md) records the reference pattern and immutable application image.

## Configuration

- [Inputs and service lifecycle](#inputs-and-service-lifecycle)
- [Chart defaults and overrides](#chart-defaults-and-overrides)
- [Versioning and Helm behavior](#versioning-and-helm-behavior)

### Inputs and service lifecycle

Required root inputs are `aws_region`, `cluster_name`, `cluster_endpoint` and `cluster_certificate_authority_data`. Providers obtain renewable tokens through `aws eks get-token`, as in platform-bootstrap.

The root owns `namespace`, default `bookinfo`; it rejects known shared/system namespaces. For a new deployment, check namespace ownership before applying. For updates, reconcile the existing namespace and releases with the pillar state. Never adopt another owner's resources.

`enable_ratings`, `enable_details`, `enable_review` and `enable_productpage` default to true. The corresponding `ratings`, `details`, `review` and `productpage` objects expose the same fields as bootstrap: `release_name`, `namespace`, `repository`, `chart_name`, `chart_version`, `context`, `context_sensitive` and `helm_options`. Omitted scalar fields use child defaults. A service namespace override must equal the shared root namespace.

Setting a service enable flag to false removes that release and its chart resources while retaining the namespace and the other releases; this is an application interruption requiring a reviewed plan.

### Chart defaults and overrides

Each service defaults to a release named after it, bundled chart (`0.2.2` for productpage, `0.1.2` for the other services), no remote repository, a 600-second Helm wait and two retained release revisions.

Empty `chart_name` selects `charts/<service>` relative to the Bookinfo module root. The service child resolves that directory from `path.module`, so the same layout works in a copied Terragrunt module.

Repository/chart overrides must preserve the Bookinfo Service name, ports and application contract; they require compatibility review. Outputs describe the selected Bookinfo contract and do not discover arbitrary replacement-chart resources.

Each service's `charts/<service>/values.yaml` contains its complete supported defaults, including image, environment, resources, probes, placement and security. The library supplies named templates without importing hidden defaults. The normal Dev leaf supplies environment wiring without image inputs.

The root uses local child sources and the leaf uses a local pillar source. Independent version selection, publication and release automation are outside the final demo; [ADR 0008](../../../docs/decisions/0008-bookinfo-service-charts.md) records that limit.

`context` and `context_sensitive` use Helm set notation and its value parsing. For example, this changes ratings' CPU request and Helm timeout while retaining its other defaults:

```hcl
ratings = {
  context = {
    "resources.requests.cpu" = "75m"
  }
  helm_options = {
    timeout = 720
  }
}
```

Each release renders only the adjacent `values.override.yaml` through `templatefile` into `helm_release.values`. Ratings, details and review start with `{}`; productpage supplies Ingress inputs and annotation defaults. Helm loads `charts/<service>/values.yaml` itself.

Precedence is chart defaults, then the rendered override, then Helm `context`/`context_sensitive` set values. Terraform directives stay outside the chart so `helm show values`, `helm template` and packaged-chart consumers can use it directly.

### Versioning and Helm behavior

Override edits change the corresponding Terraform values input. Chart defaults, including images and resources, belong to the chart release: bump `Chart.yaml` and the child's matching `chart_version` default whenever releasing a default or template change. A local chart edit alone can produce a no-change Terraform plan at the same version.

Library edits require a library version bump, updated dependencies/locks and a consuming chart version bump. No source-hash trigger or leaf image input is added.

Plan success does not validate chart templates when Helm lint is disabled; run the local checks before applying.

Charts may later move to a dedicated repository. Package each application chart with its library dependency, publish immutable versions, and select the repository/chart/version through the existing module inputs. Terraform's override template does not read the bundled chart's defaults, so an external chart supplies its own defaults.

That future migration must also update or remove the leaf's local dependency-build hooks. The current source uses local charts; external publication is outside the final demo.

`context_sensitive` provides interface parity with bootstrap; the selected Bookinfo images need no credentials. Sensitive values are redacted in normal Terraform output but may be stored in Terraform state and Helm release Secrets. Keep real credentials out of files and tests.

The full typed `helm_options` object follows bootstrap. Bookinfo defaults keep `wait=true`, `create_namespace=false`, `dependency_update=true`, `reset_values=true`, `reuse_values=false`, `atomic=false`, `cleanup_on_fail=false`, `take_ownership=false` and `upgrade_install=true`.

Callers can set `helm_options.upgrade_install=false` for an individual service. Failed operations retain evidence for diagnosis. Overrides that change readiness, adoption or cleanup need review before use.

The service sections below describe current chart defaults. The [runtime capacity record](../../../docs/validation.md#current-workflow-verification) separates earlier budgets from the current `1000m/1024Mi` tests. Current public/internal runs and resource readback are recorded; short samples do not establish sustained capacity.

## Ratings behavior

The chart renders exactly a Deployment and ClusterIP Service named `ratings`. Its current defaults request `50m` CPU and `64Mi` memory, with no CPU limit and a `128Mi` memory limit.

Requests must use positive integer millicores (`m`) and positive integer MiB (`Mi`). Limits are optional: omit a key or set it to null to leave that limit unset. The chart removes null limit entries, omits an empty limits map and passes explicit limits through without custom limits validation. The image must include an immutable SHA-256 digest.

One replica runs on `workload=main`, with `Recreate` updates, UID 1000, RuntimeDefault seccomp, dropped capabilities and no mounted ServiceAccount token. Recreate updates accept downtime.

Startup and readiness probes call local `/health`; they do not prove dependency connectivity. There is no liveness probe, HPA, PVC, application IAM or Istio configuration.

`SERVICE_VERSION=v1` selects synthetic in-memory data. The upstream POST route can still mutate that data for trusted internal callers; the executed deployment checks and load workload use GET only. Ratings remains internal at `http://ratings.bookinfo.svc.cluster.local:9080`, with the namespace reflected in the `services` output.

Initial Dev startup and finite GET checks passed at their recorded resources. Later bounded application runs have separate evidence in [validation](../../../docs/validation.md#current-workflow-verification); they do not establish sustained sizing for this service.

## Details behavior

Details renders one Deployment and one ClusterIP Service named `details`, using the same workload/security/probe defaults as ratings. Its pinned `examples-bookinfo-details-v1:1.20.3` image runs as UID 1000 on port 9080. `ENABLE_EXTERNAL_BOOK_SERVICE="false"` selects built-in book data, so `/details/0` needs no external book API. Current requests are `50m/64Mi`, with no CPU limit and a `128Mi` memory limit.

The configured address is `http://details.bookinfo.svc.cluster.local:9080`, reflected in `services.details`. Local render checks cover the image, data flag, health probes, resources and placement.

Dev startup and productpage-to-details HTTP connectivity pass. Sustained-load sizing remains unverified.

## Review behavior

The Deployment, Service and release are named `review`; the pinned image is `examples-bookinfo-reviews-v2:1.20.3`. It serves `/reviews/0` and local `/health` on port 9080. `ENABLE_RATINGS="true"`, `RATINGS_HOSTNAME=ratings`, `RATINGS_SERVICE_PORT="9080"` and `STAR_COLOR=black` configure its dependency on the ratings Service in the shared namespace. `LOG_DIR=/tmp/logs` uses the writable container filesystem; no volume is added.

The chart sets its default UID to `1001`, retaining non-root execution, RuntimeDefault seccomp and container security settings. Current requests are `100m/256Mi`, with no CPU limit and a `512Mi` memory limit. One replica uses the shared main placement, Recreate strategy and local health probes.

Its configured address is `http://review.bookinfo.svc.cluster.local:9080`, available in `services.review`.

Dev startup and the live review-to-ratings call pass; productpage's real review response includes ratings `5` and `4` with black stars. Sustained-load memory sizing remains unverified. The local health endpoint does not prove ratings connectivity.

## Productpage behavior

Productpage renders one Deployment and one ClusterIP Service named `productpage`. Its Service exposes port `80` to container port `9080`. The pinned `examples-bookinfo-productpage-v1:1.20.3` image retains UID 1000 and its upstream eight-worker Gunicorn command.

The effective Dev baseline requests and limits are both `1000m/1024Mi`, owned by [its chart defaults](charts/productpage/values.yaml). Hold the baseline fixed while measuring capacity.

The recorded deployment passed startup with the earlier `100m/256Mi` requests and `500m/512Mi` limits. Productpage used about `264Mi` in that sample, slightly above its then-current memory request and below its limit; this historical memory sample does not validate the new defaults or sustained-load sizing. Later workflow runs checked the current baseline at bounded loads, as recorded above.

Explicit host/port settings connect it to `details`, `review` and `ratings` on port `9080` in the shared namespace. `REVIEWS_HOSTNAME=review` matches the local singular Service name, and `FLOOD_FACTOR="0"` retains ordinary upstream behavior.

Local `/health` probes check the process. A successful `/productpage` response alone does not prove dependencies are healthy; the executed deployment checks separately verified productpage-to-details/review and review-to-ratings connectivity.

The root exports `internal_url`, default `http://productpage.bookinfo.svc.cluster.local/productpage`, and `services.productpage` with its name, DNS address and ports. The URL follows the shared namespace override and becomes null when productpage is disabled. It is a configuration reference, not a readiness signal. Its optional Ingress is described below.

## Productpage Ingress

Configure exposure through the root `productpage` object, matching bootstrap's service-owned configuration. `ingress_enable` defaults to false, `ingress_host` to an empty string and `ingress_annotations` to an empty map.

The child merges annotation defaults with caller keys last and passes the result to its Helm chart as values. The chart renders one Ingress named `bookinfo`, class `alb`, with Prefix `/` routed to the productpage Service on port 80. TLS terminates at the ALB; no TLS Secret is created.

The [Dev leaf](../../live/dev/ap-southeast-1/platform/pillars/bookinfo/terragrunt.hcl) enables exposure using cluster, VPC, DNS and ACM outputs. Its configuration follows this shape:

```hcl
tags = include.root.locals.tags

productpage = {
  ingress_enable = true
  ingress_host   = "bookinfo.${trimsuffix(dependency.dns.outputs.name, ".")}"
  ingress_annotations = {
    "alb.ingress.kubernetes.io/load-balancer-name" = local.prefix
    "alb.ingress.kubernetes.io/group.name"         = local.prefix
    "alb.ingress.kubernetes.io/subnets"            = join(",", dependency.vpc.outputs.public_subnets)
    "alb.ingress.kubernetes.io/certificate-arn"    = dependency.acm.outputs.acm_certificate_arn
  }
}
```

Defaults select an internet-facing IPv4 ALB, IP targets, HTTP backends, listeners on 80/443, redirect to HTTPS and the same TLS policy as Grafana.

Bookinfo health checks use `/health`, port `traffic-port`, protocol `HTTP` and success code `200`. The leaf supplies the shared ALB name/group, public subnets and validated certificate.

Both Bookinfo and bootstrap leaves pass `tags = include.root.locals.tags`. Bookinfo builds the ALB tags annotation from `var.tags`; empty tags omit it, and an explicit annotation overrides the generated value. The bootstrap root follows the same tag convention for Grafana.

Both Dev source leaves omit `group.order`; their exact host rules do not overlap. At the earlier coexistence checkpoint, Bookinfo used default ordering and Grafana retained order `10`. That observation did not establish that both deployed Ingresses omitted the annotation. Later bootstrap reconciliation has a no-change plan; its evidence is recorded separately in the validation record.

The module validates the hostname and rejects null annotation values, matching Grafana's annotation interface. The Dev leaf supplies the shared ALB settings. Deployment checks verify their agreement with the group and the certificate's region, account, issuance and hostname coverage.

ALB Controller merges tags across group members. Different keys can coexist; the same key with different values causes a conflict. Keep shared keys consistent across Bookinfo root tags and explicit Ingress annotation overrides. See the [controller v3.5.0 tag merge](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.5.0/pkg/ingress/model_build_tags.go).

Shared annotations can affect Grafana and other group members. Review their effective values before applying overrides; local validation cannot enforce agreement with another deployed state.

`context`/`context_sensitive` retain Helm precedence over the generated values and are compatibility overrides owned by the platform maintainer. Use the typed ingress fields for exposure changes so `public_url` and `ingress_name` describe the configured chart contract.

The root exports `ingress_name` and `public_url` (`https://<host>/productpage`), both null when Ingress or productpage is disabled. `internal_url` and `services` remain available when only Ingress is disabled.

ExternalDNS owns Bookinfo's endpoint and TXT records from the Ingress rule; this pillar adds no Terraform DNS records, ALB, target groups or IAM resources. Outputs do not prove DNS, TLS or target readiness.

The platform maintainer confirmed exposure removal/restoration in the validation record. That confirmation is recorded separately from agent-executed evidence. Any future repetition requires an authorized interruption.

To remove exposure, change only `productpage.ingress_enable` to false in the leaf while retaining the other configuration, rebuild dependencies and inspect a fresh plan. Expect one productpage Helm release update: only its Ingress disappears, while all Deployments and Services remain.

During an authorized apply, retain ALB Controller and ExternalDNS and verify Bookinfo's DNS records, listener rule and target group disappear while Grafana and the shared ALB remain.

Re-enable the same field and use a fresh reviewed plan to restore exposure. Local tests cover the planned diff; exposure removal/restoration is user-verified. Readiness checks and successful access alone do not prove removal or restoration behavior.

## Local verification and chart dependencies

From the repository root, use Terraform `1.16.4` to check formatting:

```bash
terraform fmt -check -recursive infra/terraform-modules/bookinfo
```

The [setup guide](../../../docs/setup.md#verify-the-setup) owns deployment and readiness checks. The [validation record](../../../docs/validation.md) retains the earlier Terraform and Helm development checks and their limits.

Rebuild each service's dependency before every plan/apply that uses local charts, including after a library edit. For all four services:

```bash
helm dependency build infra/terraform-modules/bookinfo/charts/ratings --skip-refresh
helm dependency build infra/terraform-modules/bookinfo/charts/details --skip-refresh
helm dependency build infra/terraform-modules/bookinfo/charts/review --skip-refresh
helm dependency build infra/terraform-modules/bookinfo/charts/productpage --skip-refresh
```

Commit the chart lock and source; generated `charts/<service>/charts/` archives are ignored. `dependency_update` can fill a missing dependency but does not guarantee refreshing an already vendored local library.

The [Dev leaf](../../live/dev/ap-southeast-1/platform/pillars/bookinfo/terragrunt.hcl) runs all four builds in its downloaded module before every plan/apply. It consumes cluster, VPC, DNS and ACM outputs and orders Bookinfo after bootstrap. The hook runs in the Terraform working directory, as specified by the [Terragrunt hook contract](https://docs.terragrunt.com/features/units/hooks/#hook-context).

Chart releases use explicit version changes; bump the chart version and matching `chart_version` default when releasing chart changes.

The [chart relocation record](../../../docs/validation.md) records the later passing local suite: 50 Terraform cases, 57 renders including 20 optional-limit cases, 12 expected request/image rejections, four strict lints and external-chart override checks. Earlier suite counts belong to their recorded snapshots; none of these local checks establishes deployment of the current defaults.

## Ownership and recovery

The root owns the namespace; Helm owns each service's Deployment, Service and release metadata. Productpage exposure belongs to its chart. Per-run load cleanup must preserve all of them.

The [validation record](../../../docs/validation.md) distinguishes user-confirmed exposure removal/restoration from agent-executed checks of the ready four-service deployment.

The following recovery procedure is guidance for a future authorized change and has not been exercised as a live failure-recovery test.

For a failed application update, inspect release/Pod events, restore the prior reviewed chart/image/configuration, rebuild dependencies and apply a fresh scoped plan. Do not wipe the namespace or force ownership/finalizers as a recovery shortcut. Full-pillar removal remains a separate authorized operation.
