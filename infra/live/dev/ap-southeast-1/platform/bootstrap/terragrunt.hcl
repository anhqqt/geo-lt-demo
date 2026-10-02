include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/infra/terraform-modules//platform-bootstrap"
}

dependency "cluster" {
  config_path = "../cluster"
}

dependency "vpc" {
  config_path = "../../core/vpc"
}

dependency "dns" {
  config_path = "../../../global/dns"
}

dependency "identity" {
  config_path = "../../../global/identity"
}

dependency "acm" {
  config_path = "../../core/acm"
}

locals {
  prefix = "${include.root.locals.environment.project}-${include.root.locals.account.environment}-${include.root.locals.region.region_code}"
}

inputs = {
  aws_region                         = include.root.locals.region.aws_region
  tags                               = include.root.locals.tags
  cluster_name                       = dependency.cluster.outputs.cluster_name
  cluster_endpoint                   = dependency.cluster.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.cluster.outputs.cluster_certificate_authority_data
  vpc_id                             = dependency.vpc.outputs.vpc_id
  cluster_arn                        = dependency.cluster.outputs.cluster_arn
  enable_kube_prometheus_stack       = true
  enable_k6_operator                 = true
  enable_metrics_server              = true
  enable_external_dns                = true
  enable_alb_controller              = true
  enable_cluster_autoscaler          = true

  external_dns = {
    dns_zone_id   = dependency.dns.outputs.id
    dns_zone_name = trimsuffix(dependency.dns.outputs.name, ".")
  }

  k6_operator = {
    github_oidc_provider_arn = dependency.identity.outputs.arn
    github_oidc_subject      = "repo:anhqqt@61163704/geo-lt-demo@1398407508:ref:refs/heads/main"
  }

  kube_prometheus_stack = {
    grafana_ingress_enable = true
    grafana_ingress_host   = "grafana.${trimsuffix(dependency.dns.outputs.name, ".")}"
    grafana_ingress_annotations = {
      "alb.ingress.kubernetes.io/load-balancer-name" = local.prefix
      "alb.ingress.kubernetes.io/group.name"         = local.prefix
      "alb.ingress.kubernetes.io/subnets"            = join(",", dependency.vpc.outputs.public_subnets)
      "alb.ingress.kubernetes.io/certificate-arn"    = dependency.acm.outputs.acm_certificate_arn
    }
  }
}
