resource "kubectl_manifest" "argocd_application_bucket_lister" {
  yaml_body = templatefile("${path.module}/applications/bucket-lister/argocd-application.yaml", {
    clusterArn = module.eks.cluster_arn
    awsRegion  = data.aws_region.this.id
    roleArn    = module.open_telemetry_iam_role.arn
    secretsKey = aws_secretsmanager_secret.open_telemetry.id

    awsAccountId : data.aws_caller_identity.this.id
    domainName : "${var.project_name}.${var.hosted_zone}"
    projectName : var.project_name
  })

  depends_on = [aws_eks_capability.argocd]
}

module "bucket_lister_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name            = "${var.project_name}-bucket-lister"
  description     = "TF: IAM role used by the bucket-lister application"
  use_name_prefix = false

  trust_policy_permissions = {
    EksPodIdentity = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["pods.eks.amazonaws.com"]
      }]
      conditions = [{
        test     = "StringLike"
        variable = "aws:SourceArn"
        values   = [module.eks.cluster_arn]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    AllowListS3Buckets = {
      effect = "Allow"
      actions = [
        "s3:ListAllMyBuckets",
      ]
      resources = ["*"]
    }
  }
}
