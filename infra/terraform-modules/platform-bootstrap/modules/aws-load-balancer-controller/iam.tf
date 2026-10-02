module "pod_identity" {
  source          = "terraform-aws-modules/eks-pod-identity/aws"
  version         = "2.9.0"
  region          = var.aws_region
  name            = "${var.cluster_name}-alb-controller"
  use_name_prefix = false
  associations = {
    this = {
      cluster_name         = var.cluster_name
      namespace            = var.namespace
      service_account      = "alb-controller"
      disable_session_tags = false
    }
  }
  attach_aws_lb_controller_policy = true
  aws_lb_controller_policy_name   = "${var.cluster_name}-alb-controller"
  tags                            = var.tags
}
