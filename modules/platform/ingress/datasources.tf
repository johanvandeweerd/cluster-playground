data "aws_region" "this" {
}

data "aws_caller_identity" "this" {
}

data "aws_default_tags" "this" {
}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = [var.project_name]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }

  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-public-*"]
  }
}

data "aws_security_group" "this" {
  vpc_id = data.aws_vpc.this.id

  filter {
    name   = "tag:aws:eks:cluster-name"
    values = [var.project_name]
  }
}

data "aws_route53_zone" "this" {
  name = var.hosted_zone
}
