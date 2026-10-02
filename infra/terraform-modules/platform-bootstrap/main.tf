module "alb_controller" {
  count             = var.enable_alb_controller ? 1 : 0
  source            = "./modules/aws-load-balancer-controller"
  release_name      = var.alb_controller.release_name
  namespace         = var.alb_controller.namespace
  repository        = var.alb_controller.repository
  chart_name        = var.alb_controller.chart_name
  chart_version     = var.alb_controller.chart_version
  context           = var.alb_controller.context
  context_sensitive = var.alb_controller.context_sensitive
  helm_options      = var.alb_controller.helm_options
  cluster_name      = var.cluster_name
  aws_region        = var.aws_region
  vpc_id            = var.vpc_id
  tags              = var.tags
}

module "cluster_autoscaler" {
  count             = var.enable_cluster_autoscaler ? 1 : 0
  source            = "./modules/cluster-autoscaler"
  release_name      = var.cluster_autoscaler.release_name
  namespace         = var.cluster_autoscaler.namespace
  repository        = var.cluster_autoscaler.repository
  chart_name        = var.cluster_autoscaler.chart_name
  chart_version     = var.cluster_autoscaler.chart_version
  context           = var.cluster_autoscaler.context
  context_sensitive = var.cluster_autoscaler.context_sensitive
  helm_options      = var.cluster_autoscaler.helm_options
  cluster_name      = var.cluster_name
  aws_region        = var.aws_region
  tags              = var.tags
}

module "external_dns" {
  count             = var.enable_external_dns ? 1 : 0
  source            = "./modules/external-dns"
  release_name      = var.external_dns.release_name
  namespace         = var.external_dns.namespace
  repository        = var.external_dns.repository
  chart_name        = var.external_dns.chart_name
  chart_version     = var.external_dns.chart_version
  context           = var.external_dns.context
  context_sensitive = var.external_dns.context_sensitive
  helm_options      = var.external_dns.helm_options
  cluster_name      = var.cluster_name
  aws_region        = var.aws_region
  dns_zone_id       = var.external_dns.dns_zone_id
  dns_zone_name     = var.external_dns.dns_zone_name
  tags              = var.tags
}

module "metrics_server" {
  count             = var.enable_metrics_server ? 1 : 0
  source            = "./modules/metrics-server"
  release_name      = var.metrics_server.release_name
  namespace         = var.metrics_server.namespace
  repository        = var.metrics_server.repository
  chart_name        = var.metrics_server.chart_name
  chart_version     = var.metrics_server.chart_version
  context           = var.metrics_server.context
  context_sensitive = var.metrics_server.context_sensitive
  helm_options      = var.metrics_server.helm_options
}

module "k6_operator" {
  count                    = var.enable_k6_operator ? 1 : 0
  source                   = "./modules/k6-operator"
  release_name             = var.k6_operator.release_name
  namespace                = var.k6_operator.namespace
  runner_namespace         = var.k6_operator.runner_namespace
  repository               = var.k6_operator.repository
  chart_name               = var.k6_operator.chart_name
  chart_version            = var.k6_operator.chart_version
  context                  = var.k6_operator.context
  context_sensitive        = var.k6_operator.context_sensitive
  helm_options             = var.k6_operator.helm_options
  cluster_name             = var.cluster_name
  cluster_arn              = var.cluster_arn
  github_oidc_provider_arn = var.k6_operator.github_oidc_provider_arn
  github_oidc_subject      = var.k6_operator.github_oidc_subject
  tags                     = var.tags
}

module "kube_prometheus_stack" {
  count                  = var.enable_kube_prometheus_stack ? 1 : 0
  source                 = "./modules/kube-prometheus-stack"
  grafana_ingress_enable = var.kube_prometheus_stack.grafana_ingress_enable
  grafana_ingress_host   = var.kube_prometheus_stack.grafana_ingress_host
  grafana_ingress_annotations = merge(
    length(var.tags) == 0 ? {} : {
      "alb.ingress.kubernetes.io/tags" = join(",", [for key, value in var.tags : "${key}=${value}"])
    },
    var.kube_prometheus_stack.grafana_ingress_annotations,
  )
  release_name      = var.kube_prometheus_stack.release_name
  namespace         = var.kube_prometheus_stack.namespace
  repository        = var.kube_prometheus_stack.repository
  chart_name        = var.kube_prometheus_stack.chart_name
  chart_version     = var.kube_prometheus_stack.chart_version
  context           = var.kube_prometheus_stack.context
  context_sensitive = var.kube_prometheus_stack.context_sensitive
  helm_options      = var.kube_prometheus_stack.helm_options

  depends_on = [module.alb_controller, module.external_dns]
}
