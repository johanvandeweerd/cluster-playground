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
      awsRegion = data.aws_region.this.region
      email     = var.letsencrypt_email
    }
  })
}

# IAM
module "iam_role" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name            = "${var.project_name}-cert-manager"
  description     = "TF: IAM role used by Certificate Manager for IRSA."
  use_name_prefix = "false"

  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = [data.aws_route53_zone.this.arn]
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.project_name
  namespace       = "cert-manager"
  service_account = "cert-manager"
  role_arn        = module.iam_role.iam_role_arn
}
