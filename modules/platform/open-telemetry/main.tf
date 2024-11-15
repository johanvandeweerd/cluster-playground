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
      awsRegion   = data.aws_region.this.name
      clusterName = var.project_name
      roleArn     = module.iam_role.iam_role_arn
    }
  })
}

# IAM
module "iam_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name        = "${var.project_name}-open-telemetry"
  role_description = "TF: IAM role used by Open Telemetry for IRSA."

  oidc_providers = {
    (var.project_name) = {
      provider                   = var.kubernetes_oidc_provider
      provider_arn               = var.kubernetes_oidc_provider_arn
      namespace_service_accounts = ["open-telemetry:open-telemetry"]
    }
  }

  role_policy_arns = {
    "cloudwatch" = aws_iam_policy.cloudwatch.arn
  }
}

resource "aws_iam_policy" "cloudwatch" {
  name        = "${var.project_name}-open-telemetry-cloudwatch"
  description = "TF: IAM policy to allow read Cloudwatch logs"

  policy = data.aws_iam_policy_document.cloudwatch.json
}

data "aws_iam_policy_document" "cloudwatch" {
  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
      "logs:GetLogGroupFields",
      "logs:GetLogRecord",
    ]
    resources = ["*"]
  }
}
