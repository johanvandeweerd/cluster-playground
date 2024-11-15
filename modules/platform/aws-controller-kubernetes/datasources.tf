data "aws_partition" "this" {
}

data "aws_region" "this" {
}

data "aws_caller_identity" "this" {
}

data "aws_eks_cluster" "this" {
  name = var.project_name
}
