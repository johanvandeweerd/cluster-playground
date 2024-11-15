module "httpbin" {
  source = "./httpbin"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision
}

module "bucket_lister" {
  source = "./bucket-lister"

  project_name = var.project_name

  git_url      = var.git_url
  git_revision = var.git_revision
}
