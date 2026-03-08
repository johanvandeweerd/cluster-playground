resource "kubectl_manifest" "argocd_application_opentelemetryoperator" {
  yaml_body = templatefile("${path.module}/applications/open-telemetry-operator/argocd-application.yaml", {
    clusterArn = module.eks.cluster_arn
  })

  depends_on = [aws_eks_capability.argocd]
}
