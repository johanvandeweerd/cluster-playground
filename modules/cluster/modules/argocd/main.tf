resource "helm_release" "this" {
  name  = "argocd"
  chart = "${path.module}/chart"

  dependency_update = true

  namespace        = "argocd"
  create_namespace = true

  set {
    name = "checksum"
    value = md5(join("\n", [
      for filename in fileset(path.module, "chart/**/**.yaml") : file("${path.module}/${filename}")
    ]))
  }

  set {
    name  = "argo-cd.server.ingress.hostname"
    value = "argocd.${var.domain_name}"
  }

  set {
    name  = "cluster.name"
    value = var.project_name
  }

  set {
    name  = "role.arn"
    value = module.iam_role.iam_role_arn
  }

  set {
    name  = "aws.region"
    value = data.aws_region.this.name
  }

  set {
    name  = "git.url"
    value = var.git_url
  }
}

module "iam_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name        = "${var.project_name}-argocd"
  role_description = "TF: IAM role used by job for creating secret with Github SSH key."

  oidc_providers = {
    (var.project_name) = {
      provider                   = var.kubernetes_oidc_provider
      provider_arn               = var.kubernetes_oidc_provider_arn
      namespace_service_accounts = ["argocd:argocd"]
    }
  }

  role_policy_arns = {
    "secrets-manager-argocd-read-only" = aws_iam_policy.secrets_manager_argocd_read_only.arn
  }
}

resource "aws_iam_policy" "secrets_manager_argocd_read_only" {
  name        = "${var.project_name}-secrets-manager-argocd-read-only"
  description = "TF: IAM policy to allow read access for secrets of Argocd"

  policy = data.aws_iam_policy_document.secrets_manager_argocd_read_only.json
}

data "aws_iam_policy_document" "secrets_manager_argocd_read_only" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:secret:${var.project_name}/argocd/*"
    ]
  }
}

resource "aws_secretsmanager_secret" "ssh_key" {
  name                    = "${var.project_name}/argocd/ssh-key"
  description             = "TF: Secret for Github SSH key used by Argocd"
  recovery_window_in_days = 0
}

data "local_file" "ssh_key" {
  filename = "${path.module}/../../../../id_rsa"
}

resource "aws_secretsmanager_secret_version" "ssh_key" {
  secret_id     = aws_secretsmanager_secret.ssh_key.id
  secret_string = data.local_file.ssh_key.content
}
