resource "kubectl_manifest" "argocd_application_helloservice" {
  yaml_body = templatefile("${path.module}/applications/hello-service/argocd-application.yaml", {
    clusterArn = module.eks.cluster_arn
    domainName = "${var.project_name}.${var.hosted_zone}"
    kafka = {
      address = split(",", module.msk.bootstrap_brokers[0])[0]
      topic   = "hello-service"
    }
  })

  depends_on = [aws_eks_capability.argocd]
}

resource "kubectl_manifest" "argocd_application_messageservice" {
  yaml_body = templatefile("${path.module}/applications/message-service/argocd-application.yaml", {
    clusterArn = module.eks.cluster_arn
  })

  depends_on = [aws_eks_capability.argocd]
}


resource "kubectl_manifest" "argocd_application_auditservice" {
  yaml_body = templatefile("${path.module}/applications/audit-service/argocd-application.yaml", {
    clusterArn = module.eks.cluster_arn
    kafka = {
      address = split(",", module.msk.bootstrap_brokers[0])[0]
      topic   = "hello-service"
    }
  })

  depends_on = [aws_eks_capability.argocd]
}

