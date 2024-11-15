module "aws_controller_kubernetes" {
  source = "./aws-controller-kubernetes"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision

  kubernetes_oidc_provider     = var.kubernetes_oidc_provider
  kubernetes_oidc_provider_arn = var.kubernetes_oidc_provider_arn
}

module "cert_manager" {
  source = "./cert-manager"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision

  kubernetes_oidc_provider     = var.kubernetes_oidc_provider
  kubernetes_oidc_provider_arn = var.kubernetes_oidc_provider_arn
}

module "external_secrets" {
  source = "./external-secrets"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision

  kubernetes_oidc_provider     = var.kubernetes_oidc_provider
  kubernetes_oidc_provider_arn = var.kubernetes_oidc_provider_arn
}

module "ingress" {
  source = "./ingress"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision

  kubernetes_oidc_provider     = var.kubernetes_oidc_provider
  kubernetes_oidc_provider_arn = var.kubernetes_oidc_provider_arn
}

module "open_telemetry" {
  source = "./open-telemetry"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision

  kubernetes_oidc_provider     = var.kubernetes_oidc_provider
  kubernetes_oidc_provider_arn = var.kubernetes_oidc_provider_arn
}
