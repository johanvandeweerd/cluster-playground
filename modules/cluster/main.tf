module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.project_name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.public_subnet_ids

  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  cloudwatch_log_group_retention_in_days = 7
  enabled_log_types                      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  create_security_group      = false
  create_node_security_group = false

  iam_role_name            = "${var.project_name}-cluster"
  iam_role_use_name_prefix = false
  iam_role_description     = "TF: IAM role used by the ${var.project_name} cluster control plane."

  encryption_policy_name            = "${var.project_name}-encryption"
  encryption_policy_use_name_prefix = false
  encryption_policy_description     = "TF: IAM policy used by the ${var.project_name} cluster for encryption."
}

module "karpenter" {
  source = "./modules/karpenter"

  project_name = var.project_name

  kubernetes_endpoint          = module.eks.cluster_endpoint
  kubernetes_oidc_provider     = module.eks.oidc_provider
  kubernetes_oidc_provider_arn = module.eks.oidc_provider_arn

  private_subnet_ids = var.private_subnet_ids

  create_spot_service_linked_role = length(data.aws_iam_roles.spot.names) == 0

  depends_on = [
    module.eks
  ]
}

module "argocd" {
  source = "./modules/argocd"

  project_name = var.project_name

  kubernetes_oidc_provider     = module.eks.cluster_endpoint
  kubernetes_oidc_provider_arn = module.eks.oidc_provider_arn

  git_url             = var.git_url
  git_private_ssh_key = var.git_private_ssh_key

  domain_name = "${var.project_name}.${var.hosted_zone}"

  depends_on = [
    module.karpenter
  ]
}

module "addons" {
  source = "./modules/addons"

  project_name = var.project_name

  kubernetes_version           = module.eks.cluster_version
  kubernetes_endpoint          = module.eks.cluster_endpoint
  kubernetes_oidc_provider_arn = module.eks.oidc_provider_arn

  depends_on = [
    module.karpenter
  ]
}
