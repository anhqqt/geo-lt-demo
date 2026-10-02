include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/vpc/aws?version=6.7.3"
}

locals {
  region = include.root.locals.region
  prefix = "${include.root.locals.environment.project}-${include.root.locals.account.environment}-${local.region.region_code}"
}

inputs = {
  name                 = local.prefix
  cidr                 = local.region.vpc_cidr
  azs                  = local.region.azs
  public_subnets       = local.region.public_subnet_cidrs
  private_subnets      = local.region.private_subnet_cidrs
  public_subnet_names  = [for az in local.region.azs : "${local.prefix}-public-${az}"]
  private_subnet_names = [for az in local.region.azs : "${local.prefix}-private-${az}"]

  create_vpc             = true
  create_igw             = true
  enable_dns_support     = true
  enable_dns_hostnames   = true
  enable_ipv6            = false
  create_egress_only_igw = false

  enable_nat_gateway                  = true
  single_nat_gateway                  = true
  one_nat_gateway_per_az              = false
  reuse_nat_ips                       = false
  create_private_nat_gateway_route    = true
  create_multiple_public_route_tables = false

  manage_default_vpc            = false
  manage_default_security_group = false
  manage_default_network_acl    = false
  manage_default_route_table    = false

  map_public_ip_on_launch       = false
  public_dedicated_network_acl  = false
  private_dedicated_network_acl = false
  enable_flow_log               = false
  enable_vpn_gateway            = false
  enable_dhcp_options           = false

  public_subnet_tags       = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags      = { "kubernetes.io/role/internal-elb" = "1" }
  igw_tags                 = { Name = "${local.prefix}-igw" }
  nat_gateway_tags         = { Name = "${local.prefix}-nat" }
  nat_eip_tags             = { Name = "${local.prefix}-nat-eip" }
  public_route_table_tags  = { Name = "${local.prefix}-public-rt" }
  private_route_table_tags = { Name = "${local.prefix}-private-rt" }
  tags                     = include.root.locals.tags
}
