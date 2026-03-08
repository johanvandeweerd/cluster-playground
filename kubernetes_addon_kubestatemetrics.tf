data "aws_eks_addon_version" "kube_state_metrics" {
  kubernetes_version = var.kubernetes_version
  addon_name         = "kube-state-metrics"
  most_recent        = true
}

resource "aws_eks_addon" "kube_state_metrics" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "kube-state-metrics"
  addon_version = data.aws_eks_addon_version.kube_state_metrics.version
  configuration_values = jsonencode({
    podAnnotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "8080"
      "prometheus.io/path"   = "/metrics"
    }
  })
}
