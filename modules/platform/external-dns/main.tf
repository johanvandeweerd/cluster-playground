locals {
  module_name = basename(abspath(path.module))
}

resource "kubectl_manifest" "application" {
  yaml_body = templatefile("${path.module}/chart/application.yaml", {
    name            = local.module_name
    namespace       = local.module_name
    gitUrl          = var.git_url
    revision        = var.git_revision
    helmParameters = {
      awsRegion   = data.aws_region.this.name
      clusterName = var.cluster_name
      "external-dns.serviceAccount.annotations.eks\\\\.amazonaws\\\\.com/role-arn" = module.iam_role.iam_role_arn
    }
  })
}

# IAM
module "iam_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name        = "${var.cluster_name}-external-dns"
  role_description = "TF: IAM role used by Certificate Manager for IRSA."

  oidc_providers = {
    (var.cluster_name) = {
      provider                   = var.cluster_oidc_provider
      provider_arn               = var.cluster_oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  role_policy_arns = {
    "route53" = aws_iam_policy.route53.arn
  }
}

resource "aws_iam_policy" "route53" {
  name        = "${var.cluster_name}-external-dns-route53"
  description = "TF: IAM policy to allow external-dns to update Route53"

  policy = data.aws_iam_policy_document.route53.json
}

data "aws_iam_policy_document" "route53" {
  statement {
    effect    = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }
  statement {
    effect    = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets"
    ]
    resources = ["*"]
  }
}