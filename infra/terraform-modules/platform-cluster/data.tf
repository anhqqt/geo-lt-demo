data "aws_caller_identity" "current" {}

data "aws_subnet" "obser" {
  id = local.obser_subnet_id
}
