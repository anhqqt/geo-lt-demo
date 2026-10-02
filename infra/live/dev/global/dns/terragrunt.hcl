include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "tfr://registry.terraform.io/terraform-aws-modules/route53/aws?version=6.5.1"
}

inputs = {
  create                = true
  create_zone           = true
  name                  = include.root.locals.environment.dns_zone_name
  comment               = "Dev load-testing delegated zone"
  force_destroy         = false
  ignore_vpc            = false
  vpc                   = null
  records               = {}
  enable_dnssec         = false
  create_dnssec_kms_key = false
  tags                  = include.root.locals.tags
}
