resource "aws_secretsmanager_secret" "nginx" {
  name        = "${var.project_name}/nginx"
  description = "TF: Secret used by Nginx."
}

module "nginx_iam_role" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name            = "${var.project_name}-nginx"
  use_name_prefix = false
  description     = "TF: IAM role used by Nginx."

  trust_policy_conditions = [
    {
      variable = "aws:SourceArn"
      test     = "StringEquals"
      values   = [module.eks.cluster_arn]
    },
    {
      variable = "aws:RequestTag/kubernetes-namespace"
      test     = "StringEquals"
      values   = ["default"]
    },
    {
      variable = "aws:RequestTag/kubernetes-service-account"
      test     = "StringEquals"
      values   = ["nginx"]
    },
  ]

  attach_custom_policy = true
  policy_statements = [
    {
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      resources = [
        aws_secretsmanager_secret.nginx.arn
      ]
    }
  ]

  associations = {
    custom-association = {
      cluster_name    = module.eks.cluster_name
      namespace       = "default"
      service_account = "nginx"
    }
  }
}

resource "kubectl_manifest" "argocd_application_nginx" {
  yaml_body = templatefile("${path.module}/applications/nginx/argocd-application.yaml", {
    clusterArn  = module.eks.cluster_arn
    domainName  = "nginx.${var.project_name}.${var.hosted_zone}"
    projectName = var.project_name
  })

  depends_on = [aws_eks_capability.argocd]
}
