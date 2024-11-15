locals {
  module_name = basename(abspath(path.module))
}

resource "kubectl_manifest" "application" {
  yaml_body = templatefile("${path.module}/chart/application.yaml", {
    name      = local.module_name
    namespace = local.module_name
    gitUrl    = var.git_url
    revision  = var.git_revision
    helmParameters = {
      projectName = var.project_name
      roleArn     = aws_iam_role.this.arn
      domainName  = "${var.project_name}.${var.domain_name}"
    }
  })
}

resource "aws_iam_role" "this" {
  name               = "${var.project_name}-bucket-lister"
  description        = "TF: IAM role used by the bucket-lister application"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "assume" {
  statement {
    sid    = "AllowEksPodIdentity"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role_policy" "s3" {
  role   = aws_iam_role.this.name
  name   = "S3"
  policy = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "s3" {
  statement {
    sid    = "AllowListS3Buckets"
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
    ]
    resources = ["*"]
  }
}
