data "aws_eks_addon_version" "adot" {
  kubernetes_version = var.kubernetes_version
  addon_name         = "adot"
  most_recent        = true
}

resource "aws_eks_addon" "adot" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "adot"
  addon_version = data.aws_eks_addon_version.adot.version

  depends_on = [aws_eks_addon.cert_manager]
}
