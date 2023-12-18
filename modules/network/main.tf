module "vpc" {
  source = "registry.terraform.io/terraform-aws-modules/vpc/aws"

  name = var.name

  azs = var.azs

  cidr = var.vpc_cidr

  private_subnets     = var.private_subnets
  private_subnet_tags = {
    "karpenter.sh/discovery" = var.name
  }

  public_subnets = var.public_subnets

  create_database_subnet_group  = false
  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true
}
