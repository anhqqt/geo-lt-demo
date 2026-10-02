data "aws_partition" "current" {}

module "pod_identity" {
  source          = "terraform-aws-modules/eks-pod-identity/aws"
  version         = "2.9.0"
  region          = var.aws_region
  name            = "${var.cluster_name}-external-dns"
  use_name_prefix = false
  associations = {
    this = {
      cluster_name         = var.cluster_name
      namespace            = var.namespace
      service_account      = "external-dns"
      disable_session_tags = false
    }
  }
  attach_external_dns_policy    = true
  external_dns_policy_name      = "${var.cluster_name}-external-dns"
  external_dns_hosted_zone_arns = ["arn:${data.aws_partition.current.partition}:route53:::hostedzone/${var.dns_zone_id}"]
  tags                          = var.tags
}
