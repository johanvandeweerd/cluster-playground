data "aws_eks_addon_version" "cert_manager" {
  kubernetes_version = var.kubernetes_version
  addon_name         = "cert-manager"
  most_recent        = true
}

resource "aws_eks_addon" "cert_manager" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "cert-manager"
  addon_version = data.aws_eks_addon_version.cert_manager.version
  configuration_values = jsonencode({
    topologySpreadConstraints = [
      {
        topologyKey       = "topology.kubernetes.io/zone"
        maxSkew           = 1
        whenUnsatisfiable = "DoNotSchedule"
        minDomains        = 3
        labelSelector = {
          matchLabels = {
            "app.kubernetes.io/instance" = "cert-manager"
            "app.kubernetes.io/name"     = "cert-manager"
          }
        }
      },
      {
        topologyKey       = "kubernetes.io/hostname"
        maxSkew           = 1
        whenUnsatisfiable = "DoNotSchedule"
        labelSelector = {
          matchLabels = {
            "app.kubernetes.io/instance" = "cert-manager"
            "app.kubernetes.io/name"     = "cert-manager"
          }
        }
      },
    ]
    cainjector = {
      topologySpreadConstraints = [
        {
          topologyKey       = "topology.kubernetes.io/zone"
          maxSkew           = 1
          whenUnsatisfiable = "DoNotSchedule"
          minDomains        = 3
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/instance" = "cert-manager"
              "app.kubernetes.io/name"     = "cainjector"
            }
          }
        },
        {
          topologyKey       = "kubernetes.io/hostname"
          maxSkew           = 1
          whenUnsatisfiable = "DoNotSchedule"
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/instance" = "cert-manager"
              "app.kubernetes.io/name"     = "cainjector"
            }
          }
        },
      ]
    }
    webhook = {
      topologySpreadConstraints = [
        {
          topologyKey       = "topology.kubernetes.io/zone"
          maxSkew           = 1
          whenUnsatisfiable = "DoNotSchedule"
          minDomains        = 3
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/instance" = "cert-manager"
              "app.kubernetes.io/name"     = "webhook"
            }
          }
        },
        {
          topologyKey       = "kubernetes.io/hostname"
          maxSkew           = 1
          whenUnsatisfiable = "DoNotSchedule"
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/instance" = "cert-manager"
              "app.kubernetes.io/name"     = "webhook"
            }
          }
        },
      ]
    }
  })
}
