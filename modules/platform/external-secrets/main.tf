locals {
  module_name = basename(abspath(path.module))
}

resource "kubectl_manifest" "application" {
  yaml_body = templatefile("${path.module}/chart/application.yaml", {
    name      = local.module_name
    namespace = local.module_name
    gitUrl    = var.git_url
    revision  = var.git_revision
    helmParameters = {
      awsRegion   = data.aws_region.this.region
      clusterName = var.project_name
    }
  })
}

# IAM
module "iam_role" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name            = "${var.project_name}-external-secrets"
  description     = "TF: IAM role used by External Secrets for IRSA."
  use_name_prefix = "false"

  attach_external_secrets_policy     = true
  external_secrets_create_permission = true
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.project_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = module.iam_role.iam_role_arn
}
