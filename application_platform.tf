resource "kubectl_manifest" "argocd_application_platform" {
  yaml_body = templatefile("${path.module}/applications/platform/argocd-application.yaml", {
    clusterArn  = module.eks.cluster_arn
    clusterName = module.eks.cluster_name
  })

  depends_on = [aws_eks_capability.argocd]
}
