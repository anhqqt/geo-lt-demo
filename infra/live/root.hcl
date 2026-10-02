locals {
  account     = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  environment = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  region      = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
  versions    = read_terragrunt_config("${dirname(find_in_parent_folders("root.hcl"))}/_shared/versions.hcl").locals

  tags = {
    Project     = local.environment.project
    Environment = local.account.environment
    ManagedBy   = "Terragrunt"
  }
}

terraform_binary              = "terraform"
terraform_version_constraint  = "= ${local.versions.terraform_version}"
terragrunt_version_constraint = "= ${local.versions.terragrunt_version}"

terraform {
  extra_arguments "lock_timeout" {
    commands  = ["apply", "destroy", "import", "plan", "refresh", "taint", "untaint"]
    arguments = ["-lock-timeout=60s"]
  }
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket                             = "${local.environment.project}-${local.account.environment}-${local.account.aws_account_id}"
    key                                = "${trimprefix(path_relative_to_include("root"), "${local.account.environment}/")}/terraform.tfstate"
    region                             = local.account.state_region
    allowed_account_ids                = [local.account.aws_account_id]
    encrypt                            = true
    use_lockfile                       = true
    bucket_sse_algorithm               = "AES256"
    skip_bucket_versioning             = false
    skip_bucket_ssencryption           = false
    skip_bucket_public_access_blocking = false
    skip_bucket_enforced_tls           = false
    skip_bucket_root_access            = true
    disable_bucket_update              = false
    s3_bucket_tags                     = local.tags
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region              = "${local.region.aws_region}"
  allowed_account_ids = ["${local.account.aws_account_id}"]

  default_tags {
    tags = {
      Project     = "${local.environment.project}"
      Environment = "${local.account.environment}"
      ManagedBy   = "Terragrunt"
    }
  }
}
EOF
}
