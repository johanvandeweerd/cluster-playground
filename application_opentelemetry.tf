resource "kubectl_manifest" "argocd_application_opentelemetryoperator" {
  yaml_body = templatefile("${path.module}/applications/open-telemetry-operator/argocd-application.yaml", {
    clusterArn = module.eks.cluster_arn
  })

  depends_on = [aws_eks_capability.argocd]
}

resource "aws_secretsmanager_secret" "open_telemetry" {
  name        = "${var.project_name}/open-telemetry"
  description = "TF: Secret used by OpenTelemetry."
}

resource "kubectl_manifest" "argocd_application_opentelemetrycollectors" {
  yaml_body = templatefile("${path.module}/applications/open-telemetry-collectors/argocd-application.yaml", {
    clusterArn = module.eks.cluster_arn
    awsRegion  = data.aws_region.this.id
    roleArn    = module.open_telemetry_iam_role.arn
    secretsKey = aws_secretsmanager_secret.open_telemetry.id
  })

  depends_on = [aws_eks_capability.argocd]
}

module "open_telemetry_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name            = "${var.project_name}-open-telemetry"
  use_name_prefix = false
  description     = "TF: IAM role to be assumed by External Secrets Operator to access the secrets of Open Telemetry."

  trust_policy_permissions = {
    AllowExternalSecrets = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
      principals = [{
        type        = "AWS"
        identifiers = [module.external_secrets_iam_role.iam_role_arn]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    AllowSecretsManager = {
      sid       = "AllowReadSecretsManager"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      resources = [aws_secretsmanager_secret.open_telemetry.arn]
    }
  }
}
