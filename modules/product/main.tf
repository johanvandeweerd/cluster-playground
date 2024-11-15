module "httpbin" {
  source = "./httpbin"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision

  domain_name = var.domain_name
}

module "bucket_lister" {
  source = "./bucket-lister"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision

  domain_name = var.domain_name
}
