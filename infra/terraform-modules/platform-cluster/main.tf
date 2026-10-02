module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.26.0"

  name               = var.name
  kubernetes_version = var.kubernetes_version
  ip_family          = "ipv4"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids

  endpoint_private_access                  = true
  endpoint_public_access                   = true
  endpoint_public_access_cidrs             = ["0.0.0.0/0"]
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  enable_irsa                                  = false
  create_kms_key                               = false
  encryption_config                            = null
  enabled_log_types                            = []
  create_cloudwatch_log_group                  = false
  compute_config                               = null
  fargate_profiles                             = {}
  self_managed_node_groups                     = {}
  iam_role_name                                = "${var.name}-eks"
  iam_role_use_name_prefix                     = false
  node_security_group_enable_recommended_rules = true
  timeouts                                     = { create = "60m", update = "60m", delete = "60m" }

  eks_managed_node_groups = local.node_groups
  addons                  = local.addons
  tags                    = var.tags

}
