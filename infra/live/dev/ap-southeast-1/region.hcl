locals {
  aws_region           = "ap-southeast-1"
  region_code          = "apse1"
  azs                  = ["${local.aws_region}a", "${local.aws_region}b"]
  vpc_cidr             = "10.40.0.0/16"
  public_subnet_cidrs  = ["10.40.0.0/24", "10.40.1.0/24"]
  private_subnet_cidrs = ["10.40.16.0/20", "10.40.32.0/20"]
}
