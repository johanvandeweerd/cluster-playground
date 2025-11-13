module "fargate_profile" {
  source  = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version = "~> 21.0"

  name = "karpenter"

  cluster_name = var.project_name
  subnet_ids   = var.private_subnet_ids

  iam_role_name            = "${var.project_name}-fargate-karpenter"
  iam_role_description     = "TF: IAM role used by Fargate for karpenter profile."
  iam_role_use_name_prefix = false

  selectors = [
    { namespace = "karpenter" }
  ]
}

module "iam_roles" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = var.project_name

  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  iam_role_name                           = "${var.project_name}-karpenter"
  iam_role_description                    = "TF: IAM Role used by Karptener for IRSA."
  iam_role_use_name_prefix                = false
  iam_role_source_assume_policy_documents = [data.aws_iam_policy_document.karpenter_assume_role.json]

  node_iam_role_name            = "${var.project_name}-karpenter-node"
  node_iam_role_description     = "TF: IAM role used by Karpenter managed nodes."
  node_iam_role_use_name_prefix = false
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # IRSA is used instead of Pod Identity because Karpenter runs on Fargate and no Pod Identity pods are available yet.
  create_pod_identity_association = false
  create_instance_profile         = true
  create_access_entry             = true

  queue_name = "${var.project_name}-karpenter"
}

data "aws_iam_policy_document" "karpenter_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.kubernetes_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.kubernetes_oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.kubernetes_oidc_provider}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
  }
}

resource "helm_release" "this" {
  name  = "karpenter"
  chart = "${path.module}/chart"

  dependency_update = true

  namespace        = "karpenter"
  create_namespace = true

  set {
    name = "checksum"
    value = md5(join("\n", [
      for filename in fileset(path.module, "chart/**/**.yaml") : file("${path.module}/${filename}")
    ]))
  }

  set {
    name  = "karpenter.settings.clusterName"
    value = var.project_name
  }

  set {
    name  = "karpenter.settings.clusterEndpoint"
    value = var.kubernetes_endpoint
  }

  set {
    name  = "karpenter.settings.interruptionQueueName"
    value = module.iam_roles.queue_name
  }

  set {
    name  = "karpenter.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_roles.iam_role_arn
  }

  depends_on = [
    module.iam_roles,
    module.fargate_profile,
  ]
}

resource "aws_iam_service_linked_role" "spot" {
  count = var.create_spot_service_linked_role ? 1 : 0

  aws_service_name = "spot.amazonaws.com"
}
