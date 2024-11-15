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
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name            = "${var.project_name}-open-telemetry"
  description     = "TF: IAM role used by Open Telemetry for IRSA."
  use_name_prefix = "false"

  attach_custom_policy = true
  policy_statements = [
    {
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
  ]
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.project_name
  namespace       = "open-telemetry"
  service_account = "open-telemetry-collector"
  role_arn        = module.iam_role.iam_role_arn
}
