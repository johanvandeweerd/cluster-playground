resource "kubectl_manifest" "argocd_application_traefik" {
  yaml_body = templatefile("${path.module}/applications/traefik/argocd-application.yaml", {
    clusterArn     = module.eks.cluster_arn
    hostName       = "loadbalancer.${var.project_name}.${var.hosted_zone}"
    targetGroupArn = module.alb.target_groups["traefik"].arn
  })

  depends_on = [aws_eks_capability.argocd]
}
