module "external_secrets_iam_role" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name            = "${var.project_name}-external-secrets"
  use_name_prefix = false
  description     = "TF: IAM role used by External Secrets."

  trust_policy_conditions = [
    {
      variable = "aws:SourceArn"
      test     = "StringEquals"
      values   = [module.eks.cluster_arn]
    },
    {
      variable = "aws:RequestTag/kubernetes-namespace"
      test     = "StringEquals"
      values   = ["external-secrets"]
    },
    {
      variable = "aws:RequestTag/kubernetes-service-account"
      test     = "StringEquals"
      values   = ["external-secrets"]
    },
  ]

  associations = {
    custom-association = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }
}

resource "kubectl_manifest" "argocd_application_nginx" {
  yaml_body = templatefile("${path.module}/applications/external-secrets/argocd-application.yaml", {
    clusterArn = module.eks.cluster_arn
  })

  depends_on = [aws_eks_capability.argocd]
}
