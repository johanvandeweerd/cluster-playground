module "network" {
  source = "./modules/network"

  project_name = var.project_name
}

module "cluster" {
  source = "./modules/cluster"

  project_name = var.project_name

  git_url = var.git_url

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids

  kubernetes_version = "1.31"

  domain_name = "${var.project_name}.${var.hosted_zone}"
}

module "platform" {
  source = "./modules/platform"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision

  kubernetes_oidc_provider     = module.cluster.kubernetes_oidc_provider
  kubernetes_oidc_provider_arn = module.cluster.kubernetes_oidc_provider_arn

  hosted_zone = var.hosted_zone
}

module "product" {
  source = "./modules/product"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision

  domain_name = "${var.project_name}.${var.hosted_zone}"
}
