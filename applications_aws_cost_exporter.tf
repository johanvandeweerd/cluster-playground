module "aws_cost_exporter_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name            = "${var.project_name}-aws-cost-exporter"
  description     = "TF: IAM role used by the aws-cost-exporter application"
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
    "AllowGetCostAndUsageData" = {
      effect    = "Allow"
      actions   = ["ce:GetCostAndUsage"]
      resources = ["*"]
    }
  }
}
