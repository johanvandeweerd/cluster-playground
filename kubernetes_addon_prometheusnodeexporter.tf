data "aws_eks_addon_version" "prometheus_node_exporter" {
  kubernetes_version = var.kubernetes_version
  addon_name         = "prometheus-node-exporter"
  most_recent        = true
}

resource "aws_eks_addon" "prometheus_node_exporter" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "prometheus-node-exporter"
  addon_version = data.aws_eks_addon_version.prometheus_node_exporter.version
  configuration_values = jsonencode({
    podAnnotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9100"
      "prometheus.io/path"   = "/metrics"
    }
  })
}
