module "pod_identity" {
  source          = "terraform-aws-modules/eks-pod-identity/aws"
  version         = "2.9.0"
  region          = var.aws_region
  name            = "${var.cluster_name}-cluster-autoscaler"
  use_name_prefix = false
  associations = {
    this = {
      cluster_name         = var.cluster_name
      namespace            = var.namespace
      service_account      = "cluster-autoscaler"
      disable_session_tags = false
    }
  }
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_policy_name   = "${var.cluster_name}-cluster-autoscaler"
  cluster_autoscaler_cluster_names = [var.cluster_name]
  tags                             = var.tags
}
