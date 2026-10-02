# Platform bootstrap

- [Controller configuration](#controller-configuration)
- [Cluster Autoscaler](#cluster-autoscaler)
- [ExternalDNS](#externaldns)
- [Metrics Server](#metrics-server)
- [k6 Operator](#k6-operator)
- [kube-prometheus-stack](#kube-prometheus-stack)
- [Local validation](#local-validation)

This module installs six addon children in one bootstrap state. The platform maintainer has applied all six, including kube-prometheus-stack. Recorded checks passed for controllers, Metrics API, k6 lifecycle and cleanup, monitoring readiness, two-runner native-histogram remote write, Grafana authentication and Pod-recreation persistence.

Grafana public HTTPS is applied, with a healthy ALB target, matching DNS alias/TXT records, verified TLS and authenticated access.

Current source provisions upstream dashboard 18030 revision 8. Its apply, readback and no-change plan passed, followed by live and post-cleanup Viewer checks. The upstream display limits are accepted; custom query corrections are outside the required scope.

Genuine GitHub OIDC and Bookinfo load have subsequent workflow evidence. The [validation record](../../../docs/validation.md) owns exact results and limits.

The [Dev leaf](../../live/dev/ap-southeast-1/platform/bootstrap/terragrunt.hcl) reads five existing states: cluster, VPC, global DNS, identity and regional ACM.

AWS provider/backend configuration is inherited from the Terragrunt root; Helm and Kubernetes providers use the cluster endpoint, decoded CA and renewable `aws eks get-token` credentials. The state key remains `ap-southeast-1/platform/bootstrap/terraform.tfstate`.

## Controller configuration

[main.tf](main.tf) calls separate children through `enable_alb_controller`, `enable_cluster_autoscaler`, `enable_external_dns`, `enable_metrics_server`, `enable_k6_operator` and `enable_kube_prometheus_stack`, all defaulting to `true`. Each flag manages that addon's release and related resources.

The three AWS controllers also own Pod Identity resources; Metrics Server uses Kubernetes RBAC only. Remove controller-owned load balancers before disabling the addon during an authorized deployment lifecycle.

The root's typed `alb_controller`, `cluster_autoscaler`, `external_dns`, `metrics_server`, `k6_operator` and `kube_prometheus_stack` objects have `default = {}` and `nullable = false`. Root wiring passes each object's fields directly to its child. Optional release, namespace, repository and chart fields resolve to null when omitted; the child's defaults with `nullable = false` supply the actual values.

`context`, `context_sensitive` and `helm_options` default to empty objects.

The Dev leaf enables all six addons. It omits release configuration to use child defaults, supplies the required DNS-zone fields under `external_dns` and GitHub identity fields under `k6_operator`, and sets the Grafana ingress fields under `kube_prometheus_stack`.

Use the object only for settings that differ from the child defaults:

```hcl
enable_alb_controller = true
alb_controller = {
  namespace = "platform-system"
  helm_options = {
    timeout = 600
  }
}
```

The [child variables](modules/aws-load-balancer-controller/variables.tf) own release defaults: `alb-controller` in `kube-system`, chart `aws-load-balancer-controller` `3.5.0` from `https://aws.github.io/eks-charts`. The chart supplies its controller image default.

`helm_options` is a typed object with optional defaults for each operation setting; a partial object changes only the supplied settings. Defaults include `wait = true`, `timeout = 300` and `create_namespace = true`.

The Helm release renders [values.override.yaml](modules/aws-load-balancer-controller/values.override.yaml) with `templatefile`, using simple interpolation of `cluster_name`, `aws_region` and `vpc_id`. The template owns chart configuration.

`context` supplies additional Helm `set` values and `context_sensitive` supplies `set_sensitive` values. Validation rejects null map values and overrides of the module-owned cluster and ServiceAccount settings.

The Deployment is named `aws-load-balancer-controller` and uses ServiceAccount `alb-controller` in the selected namespace. It runs on `workload=main`, with one replica and explicit resource requests/limits. Gateway features, Service load-balancer management, WAF and Shield integrations are disabled. Installing the controller alone creates no application Ingress or ALB.

The child uses `terraform-aws-modules/eks-pod-identity/aws` `2.9.0` for its role, built-in policy and association. The role and policy use the name `<cluster_name>-alb-controller`.

The association uses the same namespace as the Helm release and ServiceAccount `alb-controller`, with session tags enabled. Trust uses the public module's default policy without project-added conditions.

Helm depends on the identity module, and the cluster must already provide the Pod Identity Agent. [Source inspection](../../../docs/validation.md) records the policy comparison with controller `v3.5.0`.

[outputs.tf](outputs.tf) exposes `aws_load_balancer_controller`, `cluster_autoscaler` and `external_dns`, each containing the addon's release name, namespace and role ARN, or null when disabled. `metrics_server` contains release name and namespace only, or null when disabled.

## Cluster Autoscaler

The [Autoscaler child](modules/cluster-autoscaler/variables.tf) defaults to release `cluster-autoscaler` in `kube-system` and chart `9.59.0` from `https://kubernetes.github.io/autoscaler`.

Its [values template](modules/cluster-autoscaler/values.override.yaml) pins image `v1.36.1` because the chart still defaults to `1.35.0`; [AWS requires the controller minor to match EKS](https://docs.aws.amazon.com/eks/latest/best-practices/cas.html). There is no separate image input; the version belongs to the tested template and chart bundle. This does not change ALB's chart-supplied image.

One replica runs on `workload=main`, using ServiceAccount `cluster-autoscaler`, with requests `100m/300Mi` and limits `500m/600Mi`.

The template enables AWS ASG discovery for the supplied cluster. Existing node groups own their discovery tags and min/max bounds; bootstrap neither creates ASGs nor changes their limits.

The public Pod Identity module `2.9.0` owns role/policy `<cluster_name>-cluster-autoscaler`, default trust, and the association in the release namespace. Its built-in policy limits scaling mutations to ASGs tagged `kubernetes.io/cluster/<cluster_name>=owned`.

`cluster_autoscaler` supports the same release, chart, context and Helm options as `alb_controller`. The child guards its AWS discovery and ServiceAccount keys against direct Helm overrides.

The deployed controller scaled the load-test group from one to two nodes for two inert CPU-request probes; CloudTrail attributes the successful AWS request to its dedicated role. Natural scale-down and probe cleanup also passed. The addon adjusts desired capacity within existing node-group bounds; it does not own those bounds.

## ExternalDNS

The [ExternalDNS child](modules/external-dns/variables.tf) defaults to chart `1.22.0` from `https://kubernetes-sigs.github.io/external-dns/`, using the chart's image `v0.22.0`. The release and ServiceAccount default to `external-dns` in `kube-system`.

Its [values template](modules/external-dns/values.override.yaml) runs one replica on `main`, with `Recreate` strategy, requests `50m/64Mi` and limits `200m/128Mi`. The chart also installs its bundled DNSEndpoint and DNSRecord CRDs; neither custom resource is used here.

When ExternalDNS is enabled, the root requires `external_dns.dns_zone_id` and `external_dns.dns_zone_name`, supplied from the existing `global/dns` outputs by the Dev leaf. Root wiring passes these fields to the child's `dns_zone_id` and `dns_zone_name` inputs.

The built-in Pod Identity policy allows record changes only in that zone, with account-wide listing permissions and default trust. Role/policy names use `<cluster_name>-external-dns`.

The controller filters by zone ID, domain, public zone type and `alb` Ingress class. It discovers hostnames from `spec.rules[].host` and destinations from Ingress ALB status. The template sets no `annotationFilter`; Grafana supplies neither ExternalDNS hostname nor hostname-source annotations.

`sync` policy and the TXT registry track records with stable cluster-name ownership and `%{record_type}-` prefixes. Keep that owner/prefix stable while records exist.

TXT ownership protects unrelated records through controller behavior, not record-level IAM restrictions. Remove and verify owned endpoint/TXT records before disabling ExternalDNS or removing its IAM. The module creates no Ingress or endpoint record.

The deployed controller passed a temporary Ingress lifecycle check under the earlier annotation-only discovery configuration: it created the A alias and TXT ownership record, removed both after source deletion, and preserved the original NS/SOA/ACM validation records.

Later Grafana and Bookinfo checks establish host-rule discovery and publication; removal of those retained endpoints under the current configuration remains unverified. CloudTrail attributes the record creation to its dedicated role; the validation record owns the exact evidence and cleanup checks.

`external_dns` groups its two DNS-zone fields with the same release/chart/Helm options as the other addons. The template owns filters, TXT ownership, ServiceAccount and one-writer settings; context overrides of those keys are rejected.

## Metrics Server

The [Metrics Server child](modules/metrics-server/variables.tf) defaults to release `metrics-server` in `kube-system`, using official chart `3.14.0` and its default image `v0.9.0`. Version 0.9 supports Kubernetes 1.34 and later, including the existing EKS 1.36 cluster.

It provides the Kubernetes Metrics API used by `kubectl top`; no HPA is created and the deployed Prometheus/Grafana stack remains separate. [Upstream requirements and compatibility](https://github.com/kubernetes-sigs/metrics-server/blob/v0.9.0/README.md#requirements).

The [values template](modules/metrics-server/values.override.yaml) places one replica on `main`, requests `100m/200Mi` and limits it to `500m/400Mi`. Chart defaults provide probes, ServiceAccount, RBAC, a ClusterIP Service and `v1beta1.metrics.k8s.io` APIService.

It needs no AWS role, Pod Identity, cluster-name or DNS input. Output `metrics_server` contains only release name and namespace, or null when disabled.

The chart keeps kubelet certificate verification enabled, prefers InternalIP and uses port 10250. Its separate APIService-to-server connection retains the chart's self-signed serving-certificate setup and `insecureSkipTLSVerify` default. The existing VPC CNI and EKS recommended node security-group rules provide the network path.

Live APIService availability and node/Pod metric reads passed; the [setup guide](../../../docs/setup.md#cluster-and-workloads) gives read-only checks.

Inspect existing APIService/Helm ownership before a fresh installation; do not adopt a second Metrics Server installation.

Disabling `enable_metrics_server` through a reviewed plan removes its chart resources and makes this Metrics API unavailable; it does not remove nodes or AWS controllers.

## k6 Operator

- [Controller and namespaces](#controller-and-namespaces)
- [Workflow access](#workflow-access)
- [Generator controls and evidence](#generator-controls-and-evidence)

### Controller and namespaces

The [k6 child](modules/k6-operator/variables.tf) defaults to chart `4.6.0` from the official Grafana repository and its image `ghcr.io/grafana/k6-operator:controller-v1.6.0`. Release `k6-operator` uses namespace `k6-operator`, with one manager on `main`, requests `100m/128Mi` and limits `500m/256Mi`.

The values template sets `rbac.namespaced=false` and watches the runner namespace, keeps the metrics Service and ServiceMonitor disabled, and lets Helm own the controller ServiceAccount, ClusterRoles/ClusterRoleBindings and leader-election Role/RoleBinding and bundled TestRun/PrivateLoadZone CRDs. The module creates no PrivateLoadZone, cloud-k6 credential or TestRun.

The controller retains the official chart's cluster-wide permissions, including Secret/log reads and PLZ-related operations. It cannot manage namespaces, ServiceAccounts or RBAC.

The [k6 child](modules/k6-operator/main.tf) lets Helm create the k6 Operator namespace with `helm_options.create_namespace = true`; the chart's `namespace.create` stays false.

`runner_namespace` defaults to `k6-runners`. [runner.tf](modules/k6-operator/runner.tf) creates that namespace only when it differs from the k6 Operator namespace, and leaves generator Pods on the namespace's `default` ServiceAccount.

Set `k6_operator.runner_namespace` equal to `k6_operator.namespace` to share a namespace without a Terraform namespace resource. Both scalar inputs have child defaults and `nullable = false`.

The chart owns the k6 Operator RBAC for both namespace layouts. No supplemental runner Role/RoleBinding or ServiceAccount is created. `WATCH_NAMESPACE` selects the runner namespace; this limits reconciliation scope while the chart's authorization remains cluster-wide, as accepted for the demo. Helm waits for any separate runner namespace before starting.

`enable_k6_operator=false` removes the release, workflow access and any Terraform-created runner namespace. Helm may leave the k6 Operator namespace behind. Remove active runs and tracked leftovers before disabling the addon because Helm owns the templated CRDs.

### Workflow access

The leaf supplies `cluster_arn` and sets `k6_operator.github_oidc_provider_arn` and `k6_operator.github_oidc_subject` for the verified repository. The repository API reports default branch `main` and immutable prefix `repo:anhqqt@61163704/geo-lt-demo@1398407508`; the leaf's exact subject ends in `:ref:refs/heads/main`.

Role `<cluster_name>-github-load-test` accepts only that subject and audience `sts.amazonaws.com`, with a six-hour maximum session and only `eks:DescribeCluster` on the existing cluster ARN.

A STANDARD EKS access entry maps the permanent role ARN to `geo-lt:load-test-runs`; no EKS access policy or administrator group is granted. Changing repository/branch identity requires re-verifying the OIDC metadata and updating this input.

The workflow Role permits create/read/delete for TestRuns and script ConfigMaps, read/delete for Jobs/Pods/Services, and read-only Events in the generator namespace. It grants no Secret, PVC, ServiceAccount, namespace, RBAC, deployment, ingress or node access, no execution/log/token subresources and no collection deletion.

Namespace RBAC does not distinguish concurrent runs. The trusted workflow selects individual objects by recorded name/UID; RBAC alone cannot enforce that selection. When namespaces are shared, a mistaken cleanup selection can delete a controller Pod; the Deployment recreates it.

### Generator controls and evidence

Output `k6_operator` contains release name, k6 Operator namespace, runner namespace/ServiceAccount, workflow role ARN and group, or null when disabled.

Runner, initializer and starter Pods use `default`; this module adds no IAM or RBAC grants to that ServiceAccount.

The TestRun sets each Pod's string-valued `automountServiceAccountToken` to `"false"`, and uses `workload=load-test` with its exact dedicated toleration. ServiceAccount defaults alone are insufficient because the k6 Operator otherwise overrides Pod token automount. The workload template owns the explicit runner/helper image pins and requests/limits.

Live checks passed for both CRDs, the controller rollout, watch scope, chart bindings and 43 Kubernetes allow/deny cases.

A five-second TestRun used two runners with one VU each, completed all four Jobs, and verified default ServiceAccount, disabled token mounts, load-test placement and cleanup. It performed local arithmetic and sleep, with no application HTTP or metric export.

That smoke used IAM/EKS metadata and impersonated Kubernetes checks. Later hosted workflow checks separately proved genuine GitHub OIDC, IAM-to-EKS authentication and token renewal. See the [validation record](../../../docs/validation.md) and [setup guide](../../../docs/setup.md#prepare-workflow-access). Monitoring is deployed through `enable_kube_prometheus_stack`; its separate runtime verification is described below.

## kube-prometheus-stack

- [Metrics and storage](#metrics-and-storage)
- [Dashboard and access](#dashboard-and-access)
- [Public ingress](#public-ingress)
- [Monitoring lifecycle and evidence](#monitoring-lifecycle-and-evidence)

The [monitoring child](modules/kube-prometheus-stack/variables.tf) defaults to release and namespace `monitoring`, chart `91.8.2`, and chart-owned images: Prometheus Operator `v0.94.1`, Prometheus `v3.15.0-distroless` and Grafana `13.2.3-distroless`. Its only Terraform resource is `helm_release.this`; root wiring depends on ALB Controller and ExternalDNS.

The child uses the same optional release/context/Helm settings as the other addons, with a 900-second Helm timeout.

### Metrics and storage

The [values template](modules/kube-prometheus-stack/values.override.yaml) keeps one Prometheus, Grafana and Operator on `workload=obser`, with explicit resource bounds and the exact dedicated toleration.

Alertmanager, node exporter, kube-state-metrics, Kubernetes scrape targets, default rules/dashboards, Grafana sidecars, test Pods and admission hooks are disabled. Chart CRDs and the three components' self-monitoring remain. No Thanos, extra collector or histogram feature flag is enabled.

Prometheus has a 20Gi RWO claim and Grafana a 1Gi RWO claim with `Recreate` strategy. Both omit `storageClassName`, so new claims use the cluster default, currently `ebs-csi-default-sc`. There is no storage-class input, duplicate StorageClass or bootstrap EBS IAM.

Prometheus retains the chart's 10-day retention default without a size limit; the initial disk is not a guarantee for every permitted load run.

### Dashboard and access

Prometheus accepts remote write at `http://monitoring-prometheus.monitoring.svc.cluster.local:9090/api/v1/write`. Grafana provisions the internal datasource with UID `prometheus` directly through the chart, without a watcher sidecar.

Current values also configure a `k6` file provider and chart-managed download of official dashboard `18030`, revision `8`, replacing `DS_PROMETHEUS` with `prometheus`.

The dashboard download init container has requests `50m/64Mi` and limits `200m/128Mi`. The file provider permits UI edits, but those edits are not versioned query corrections.

The accepted [results contract](../../../docs/architecture.md#read-the-results) uses this unmodified upstream dashboard for manual interpretation, with its display limits. Run/time filtering, live data and retained Viewer results have runtime evidence; exhaustive numerical fixtures and custom query corrections are outside the final demo scope.

Both Services remain ClusterIP; only Grafana has an ALB Ingress in the Dev leaf. The chart generates the administrator Secret; anonymous access, signup and organization creation are disabled, and new users default to Viewer.

Output `kube_prometheus_stack` exports the release, namespace, internal URLs, Grafana Service, administrator Secret name and `grafana_url`, or null when the addon is disabled. `grafana_url` is null when the addon is enabled with ingress disabled. It exports no password.

### Public ingress

The monitoring child owns three ingress inputs: `grafana_ingress_enable` defaults to `false`, `grafana_ingress_host` is required when enabled, and `grafana_ingress_annotations` defaults to `{}`.

The Dev leaf sets `kube_prometheus_stack.grafana_ingress_enable=true` and derives the hostname from the delegated zone. It supplies ALB name/group `geo-lt-dev-apse1`, existing public subnet IDs and the validated ACM certificate ARN, and omits `group.order`.

The root derives `alb.ingress.kubernetes.io/tags` from nonempty `var.tags`, then merges caller annotations last. An empty tag map adds no annotation; an explicit caller tags annotation overrides the derived value. Keep shared tag values consistent with Bookinfo.

Child defaults select an internet-facing IPv4 ALB with IP targets, HTTP 80 and HTTPS 443, redirect to HTTPS, TLS policy `ELBSecurityPolicy-TLS13-1-2-2021-06` and `/api/health` checks. Supplied annotation keys merge last and override those defaults.

The native Grafana chart renders its `alb` Ingress with Prefix `/`, an HTTPS `root_url` and secure session cookies. The module adds no Terraform Ingress, ALB lookup or DNS record.

ExternalDNS derives the hostname from the rule and creates its alias/TXT records after ALB Controller publishes the Ingress address. See the [public access procedure](../../../docs/setup.md#bookinfo-and-grafana) for observed checks, retained costs and cleanup ordering.

### Monitoring lifecycle and evidence

Live checks passed for readiness, default-class gp3 volumes, native histograms from two runners, datasource queries as Viewer, denied Viewer edits and anonymous access, and data/account retention across Pod recreation.

The original persistence checkpoint had no dashboards; its temporary run, Grafana folder/Viewer and localhost port-forwards were removed. A later monitoring-only apply installed the accepted upstream dashboard, followed by a no-change plan and Viewer checks during a real Bookinfo run and after cleanup.

Public HTTPS and retained Viewer results have separate evidence. Earlier custom-dashboard observations apply only to that dashboard revision; see the [validation record](../../../docs/validation.md#current-workflow-verification).

Setting `kube_prometheus_stack.grafana_ingress_enable=false` removes only the chart-owned Ingress and its HTTPS-specific Grafana settings while preserving the monitoring release, Services, PVCs, datasource and accounts.

Keep ALB Controller and ExternalDNS active until Grafana endpoint/TXT records and its host rule/target group are gone. The ALB remains if another Ingress still uses the group; when the final member is removed, observe ALB/listener release before disabling either controller. Live Grafana exposure removal was not exercised and is outside the final demo scope.

Disabling `enable_kube_prometheus_stack` removes the Helm release. Source inspection shows Helm removes the Grafana PVC/administrator Secret, while operator-created Prometheus PVCs and the Helm-created namespace may remain.

Actual uninstall is untested and outside the final demo scope. Ordinary run cleanup preserves monitoring; a separately authorized teardown must inventory retained claims/volumes before removing CSI or its IAM.

## Local validation

From the repository root, use Terraform `1.16.4` and Terragrunt `1.1.6` to check formatting:

```bash
terraform fmt -check -recursive infra/terraform-modules/platform-bootstrap
terragrunt --working-dir infra/live hcl fmt --check
```

These commands check formatting. The [setup guide](../../../docs/setup.md#verify-the-setup) owns deployment and readiness checks; the [validation record](../../../docs/validation.md) retains the earlier development checks and their limits. The root validates endpoint and CA syntax; it does not verify that they belong to the supplied cluster name.

Use an ordinary saved plan/apply after reviewing an addon change. The recorded deployment passed installation checks for all six releases and an exit-0 no-change plan. Future source changes require a fresh plan and deployment verification.

The temporary fixed-response HTTPS ALB probe verified controller-driven creation, ExternalDNS alias/TXT publication, public DNS, TLS/HTTP 200 and cleanup. CloudTrail attributes ALB and DNS creation to their dedicated roles.

Grafana now has a healthy IP target and verified public TLS/DNS access. Later [Bookinfo verification](../../../docs/validation.md) passed Bookinfo target health and multi-Ingress coexistence.

Grafana exposure removal and chart uninstall were not exercised and are outside the final demo scope. The [validation record](../../../docs/validation.md) distinguishes local checks, platform maintainer applies and observed runtime evidence. Review those evidence and provider compatibility limits before a future bootstrap change.
