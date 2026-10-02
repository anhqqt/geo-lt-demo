output "aws_load_balancer_controller" {
  value = var.enable_alb_controller ? {
    release_name = module.alb_controller[0].release_name
    namespace    = module.alb_controller[0].namespace
    role_arn     = module.alb_controller[0].role_arn
  } : null
}

output "cluster_autoscaler" {
  value = var.enable_cluster_autoscaler ? {
    release_name = module.cluster_autoscaler[0].release_name
    namespace    = module.cluster_autoscaler[0].namespace
    role_arn     = module.cluster_autoscaler[0].role_arn
  } : null
}

output "external_dns" {
  value = var.enable_external_dns ? {
    release_name = module.external_dns[0].release_name
    namespace    = module.external_dns[0].namespace
    role_arn     = module.external_dns[0].role_arn
  } : null
}

output "metrics_server" {
  value = var.enable_metrics_server ? {
    release_name = module.metrics_server[0].release_name
    namespace    = module.metrics_server[0].namespace
  } : null
}

output "k6_operator" {
  value = var.enable_k6_operator ? {
    release_name           = module.k6_operator[0].release_name
    namespace              = module.k6_operator[0].namespace
    workflow_role_arn      = module.k6_operator[0].workflow_role_arn
    workflow_group         = module.k6_operator[0].workflow_group
    runner_namespace       = module.k6_operator[0].runner_namespace
    runner_service_account = module.k6_operator[0].runner_service_account
  } : null
}

output "kube_prometheus_stack" {
  value = var.enable_kube_prometheus_stack ? {
    release_name         = module.kube_prometheus_stack[0].release_name
    namespace            = module.kube_prometheus_stack[0].namespace
    prometheus_url       = module.kube_prometheus_stack[0].prometheus_url
    remote_write_url     = module.kube_prometheus_stack[0].remote_write_url
    grafana_service      = module.kube_prometheus_stack[0].grafana_service
    grafana_admin_secret = module.kube_prometheus_stack[0].grafana_admin_secret
    grafana_url          = module.kube_prometheus_stack[0].grafana_url
  } : null
}
