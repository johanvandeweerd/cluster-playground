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
      "eks-chart.aws.region" = data.aws_region.this.region
    }
  })
}

# IAM
module "iam_role" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name            = "${var.project_name}-ack-eks"
  description     = "TF: IAM role used by AWS Controller for Kubernetes for EKS."
  use_name_prefix = "false"
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.project_name
  namespace       = "aws-controller-kubernetes"
  service_account = "ack-eks-controller"
  role_arn        = module.iam_role.iam_role_arn
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
    resources = ["arn:${data.aws_partition.this.id}:eks:${data.aws_region.this.region}:${data.aws_caller_identity.this.account_id}:podidentityassociation/${var.project_name}/*"]
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
