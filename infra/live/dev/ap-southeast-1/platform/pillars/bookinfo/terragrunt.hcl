include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/infra/terraform-modules//bookinfo"

  before_hook "build_ratings_chart" {
    commands = ["plan", "apply"]
    execute  = ["helm", "dependency", "build", "charts/ratings", "--skip-refresh"]
  }

  before_hook "build_details_chart" {
    commands = ["plan", "apply"]
    execute  = ["helm", "dependency", "build", "charts/details", "--skip-refresh"]
  }

  before_hook "build_review_chart" {
    commands = ["plan", "apply"]
    execute  = ["helm", "dependency", "build", "charts/review", "--skip-refresh"]
  }

  before_hook "build_productpage_chart" {
    commands = ["plan", "apply"]
    execute  = ["helm", "dependency", "build", "charts/productpage", "--skip-refresh"]
  }
}

dependency "cluster" {
  config_path = "../../cluster"
}

dependency "vpc" {
  config_path = "../../../core/vpc"
}

dependency "dns" {
  config_path = "../../../../global/dns"
}

dependency "acm" {
  config_path = "../../../core/acm"
}

locals {
  prefix = "${include.root.locals.environment.project}-${include.root.locals.account.environment}-${include.root.locals.region.region_code}"
}

dependencies {
  paths = ["../../bootstrap"]
}

inputs = {
  aws_region                         = include.root.locals.region.aws_region
  tags                               = include.root.locals.tags
  cluster_name                       = dependency.cluster.outputs.cluster_name
  cluster_endpoint                   = dependency.cluster.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.cluster.outputs.cluster_certificate_authority_data

  productpage = {
    ingress_enable = true
    ingress_host   = "bookinfo.${trimsuffix(dependency.dns.outputs.name, ".")}"
    ingress_annotations = {
      "alb.ingress.kubernetes.io/load-balancer-name" = local.prefix
      "alb.ingress.kubernetes.io/group.name"         = local.prefix
      "alb.ingress.kubernetes.io/subnets"            = join(",", dependency.vpc.outputs.public_subnets)
      "alb.ingress.kubernetes.io/certificate-arn"    = dependency.acm.outputs.acm_certificate_arn
    }
  }
}
