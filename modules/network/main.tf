locals {
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["${data.aws_region.this.name}a", "${data.aws_region.this.name}b", "${data.aws_region.this.name}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.project_name

  azs = local.azs

  cidr = local.vpc_cidr

  private_subnets = local.private_subnets
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = ""
  }

  public_subnets = local.public_subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb" = ""
  }

  create_database_subnet_group  = false
  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true
}
