data "aws_eks_addon_version" "aws_secrets_store_csi_driver_provider" {
  kubernetes_version = var.kubernetes_version
  addon_name         = "aws-secrets-store-csi-driver-provider"
  most_recent        = true
}

resource "aws_eks_addon" "aws_secrets_store_csi_driver_provider" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "aws-secrets-store-csi-driver-provider"
  addon_version = data.aws_eks_addon_version.aws_secrets_store_csi_driver_provider.version
  configuration_values = jsonencode({
    secrets-store-csi-driver = {
      syncSecret = {
        enabled = true
      }
    }
  })
}
