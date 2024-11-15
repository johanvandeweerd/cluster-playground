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
      "eks-chart.serviceAccount.annotations.eks\\\\.amazonaws\\\\.com/role-arn" = module.iam_role.iam_role_arn
      "eks-chart.aws.region"                                                    = data.aws_region.this.name
    }
  })
}

# IAM
module "iam_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name        = "${var.project_name}-ack-eks"
  role_description = "TF: IAM role used by AWS Controller for Kubernetes for EKS."

  oidc_providers = {
    (var.project_name) = {
      provider                   = var.kubernetes_oidc_provider
      provider_arn               = var.kubernetes_oidc_provider_arn
      namespace_service_accounts = ["aws-controller-kubernetes:ack-eks-controller"]
    }
  }
}

resource "aws_iam_role_policy" "pod_identity" {
  role   = module.iam_role.iam_role_name
  name   = "PodIdentity"
  policy = data.aws_iam_policy_document.pod_identity.json
}


data "aws_iam_policy_document" "pod_identity" {
  statement {
    sid    = "AllowCreatePodIdentityAssociations"
    effect = "Allow"
    actions = [
      "eks:ListPodIdentityAssociations",
      "eks:CreatePodIdentityAssociation",
    ]
    resources = [data.aws_eks_cluster.this.arn]
  }
  statement {
    sid    = "AllowDeleteUpdatePodIdentityAssociations"
    effect = "Allow"
    actions = [
      "eks:DeletePodIdentityAssociation",
      "eks:DescribePodIdentityAssociation",
      "eks:TagResource",
      "eks:UpdatePodIdentityAssociation",
    ]
    resources = ["arn:${data.aws_partition.this.id}:eks:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:podidentityassociation/${var.project_name}/*"]
  }
  statement {
    sid    = "AllowPassAndGetRole"
    effect = "Allow"
    actions = [
      "iam:PassRole",
      "iam:GetRole",
    ]
    resources = ["*"]
  }
}
