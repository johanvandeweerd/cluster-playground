module "eks_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"

  cluster_name      = var.project_name
  cluster_version   = var.kubernetes_version
  cluster_endpoint  = var.kubernetes_endpoint
  oidc_provider_arn = var.kubernetes_oidc_provider_arn

  eks_addons = {
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    coredns = {
      most_recent          = true
      configuration_values = jsonencode(yamldecode(file("${path.module}/coredns.yaml")))
    }
  }
}
