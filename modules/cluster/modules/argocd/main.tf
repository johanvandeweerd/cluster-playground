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
    name  = "git.url"
    value = var.git_url
  }

  dynamic "set_sensitive" {
    for_each = var.git_private_ssh_key != null ? [1] : []

    content {
      name  = "git.sshPrivateKey"
      value = var.git_private_ssh_key
    }
  }
}
