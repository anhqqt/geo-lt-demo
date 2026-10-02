resource "kubernetes_namespace_v1" "runner" {
  count = var.runner_namespace != var.namespace ? 1 : 0

  metadata {
    name = var.runner_namespace
  }
}
