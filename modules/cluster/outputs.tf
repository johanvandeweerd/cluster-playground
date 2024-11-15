output "kubernetes_endpoint" {
  value = module.eks.cluster_endpoint
}

output "kubernetes_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "kubernetes_oidc_provider" {
  value = module.eks.oidc_provider
}

output "kubernetes_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}
