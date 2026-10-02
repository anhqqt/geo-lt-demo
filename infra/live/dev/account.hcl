locals {
  aws_account_id = get_env("AWS_ACCOUNT_ID")
  environment    = "dev"
  state_region   = "ap-southeast-1"
}
