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
      awsRegion                                                                    = data.aws_region.this.name
      clusterName                                                                  = var.project_name
      "cert-manager.serviceAccount.annotations.eks\\\\.amazonaws\\\\.com/role-arn" = module.iam_role.iam_role_arn
    }
  })
}

# IAM
module "iam_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name        = "${var.project_name}-cert-manager"
  role_description = "TF: IAM role used by Certificate Manager for IRSA."

  oidc_providers = {
    (var.project_name) = {
      provider                   = var.kubernetes_oidc_provider
      provider_arn               = var.kubernetes_oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }

  role_policy_arns = {
    "route53" = aws_iam_policy.route53.arn
  }
}

resource "aws_iam_policy" "route53" {
  name        = "${var.project_name}-cert-mananger-route53"
  description = "TF: IAM policy to allow cert-manager to update Route53"

  policy = data.aws_iam_policy_document.route53.json
}

data "aws_iam_policy_document" "route53" {
  statement {
    effect    = "Allow"
    resources = ["arn:aws:route53:::change/*"]
    actions = [
      "route53:GetChange"
    ]
  }
  statement {
    effect    = "Allow"
    resources = ["arn:aws:route53:::hostedzone/*"]
    actions = [
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets"
    ]
  }
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "route53:ListHostedZonesByName"
    ]
  }
}

