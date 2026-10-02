include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/acm/aws?version=6.3.1"
}

dependency "dns" {
  config_path = "../../../global/dns"
}

locals {
  region = include.root.locals.region
  prefix = "${include.root.locals.environment.project}-${include.root.locals.account.environment}-${local.region.region_code}"
}

inputs = {
  zone_id                            = dependency.dns.outputs.id
  domain_name                        = "*.${trimsuffix(dependency.dns.outputs.name, ".")}"
  create_certificate                 = true
  create_route53_records             = true
  create_route53_records_only        = false
  validate_certificate               = true
  wait_for_validation                = true
  validation_allow_overwrite_records = false
  validation_method                  = "DNS"
  validation_timeout                 = "45m"
  dns_ttl                            = 60
  subject_alternative_names          = []
  key_algorithm                      = "RSA_2048"
  export                             = "DISABLED"
  tags                               = merge(include.root.locals.tags, { Name = "${local.prefix}-wildcard" })
}
