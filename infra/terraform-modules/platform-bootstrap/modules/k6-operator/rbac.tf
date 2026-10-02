resource "kubernetes_role_v1" "workflow" {
  metadata {
    name = "load-test-runs"
    namespace = var.runner_namespace != var.namespace ? (
      kubernetes_namespace_v1.runner[0].metadata[0].name
    ) : helm_release.this.namespace
  }
  rule {
    api_groups = ["k6.io"]
    resources  = ["testruns"]
    verbs      = ["create", "get", "list", "watch", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "get", "list", "watch", "delete"]
  }
  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "services"]
    verbs      = ["get", "list", "watch", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }
}
resource "kubernetes_role_binding_v1" "workflow" {
  metadata {
    name      = "load-test-runs"
    namespace = kubernetes_role_v1.workflow.metadata[0].namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.workflow.metadata[0].name
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = local.workflow_group
  }
  depends_on = [aws_eks_access_entry.workflow]
}
