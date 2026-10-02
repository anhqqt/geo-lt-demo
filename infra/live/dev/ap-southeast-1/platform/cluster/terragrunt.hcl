include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/infra/terraform-modules//platform-cluster"
}

dependency "vpc" {
  config_path = "../../core/vpc"
}

locals {
  region       = include.root.locals.region
  prefix       = "${include.root.locals.environment.project}-${include.root.locals.account.environment}-${local.region.region_code}"
  cluster_name = "${local.prefix}-main"
}

inputs = {
  name       = local.cluster_name
  aws_region = local.region.aws_region
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets
  tags       = include.root.locals.tags
}
