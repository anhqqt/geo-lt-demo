resource "helm_release" "this" {
  name                       = var.release_name
  namespace                  = var.namespace
  repository                 = var.repository
  chart                      = var.chart_name
  version                    = var.chart_version
  force_update               = var.helm_options.force_update
  wait                       = var.helm_options.wait
  timeout                    = var.helm_options.timeout
  recreate_pods              = var.helm_options.recreate_pods
  max_history                = var.helm_options.max_history
  lint                       = var.helm_options.lint
  cleanup_on_fail            = var.helm_options.cleanup_on_fail
  create_namespace           = var.helm_options.create_namespace
  disable_webhooks           = var.helm_options.disable_webhooks
  verify                     = var.helm_options.verify
  reuse_values               = var.helm_options.reuse_values
  reset_values               = var.helm_options.reset_values
  atomic                     = var.helm_options.atomic
  skip_crds                  = var.helm_options.skip_crds
  disable_crd_hooks          = var.helm_options.disable_crd_hooks
  render_subchart_notes      = var.helm_options.render_subchart_notes
  disable_openapi_validation = var.helm_options.disable_openapi_validation
  wait_for_jobs              = var.helm_options.wait_for_jobs
  dependency_update          = var.helm_options.dependency_update
  replace                    = var.helm_options.replace
  pass_credentials           = var.helm_options.pass_credentials
  take_ownership             = var.helm_options.take_ownership
  upgrade_install            = var.helm_options.upgrade_install

  values = [templatefile("${path.module}/values.override.yaml", {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
    vpc_id       = var.vpc_id
  })]

  set = [
    for key, value in var.context : {
      name  = key
      value = value
    }
  ]

  set_sensitive = [
    for key, value in var.context_sensitive : {
      name  = key
      value = value
    }
  ]

  depends_on = [module.pod_identity]
}
