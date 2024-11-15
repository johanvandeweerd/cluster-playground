data "aws_region" "this" {
}

data "aws_route53_zone" "this" {
  name = var.hosted_zone
}
