terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Project = var.project_name
    }
  }
}

provider "kubectl" {
  host                   = module.cluster.kubernetes_endpoint
  cluster_ca_certificate = base64decode(module.cluster.kubernetes_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.project_name]
  }
}

provider "kubernetes" {
  host                   = module.cluster.kubernetes_endpoint
  cluster_ca_certificate = base64decode(module.cluster.kubernetes_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.project_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.kubernetes_endpoint
    cluster_ca_certificate = base64decode(module.cluster.kubernetes_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.project_name]
    }
  }
}
