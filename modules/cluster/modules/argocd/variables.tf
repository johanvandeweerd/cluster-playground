variable "project_name" {
  description = "Name to use for the VPC, EKS cluster, etc and to use as prefix to name resources."
  type        = string
}

variable "kubernetes_oidc_provider" {
  description = "The name of the OIDC provider of the Kubernetes cluster"
  type        = string
}

variable "kubernetes_oidc_provider_arn" {
  description = "The ARN of the OIDC provider of the Kubernetes cluster"
  type        = string
}

variable "git_url" {
  description = "The Git URL used in the Argpcd application manifests."
  type        = string
}

variable "domain_name" {
  description = "The domain name to use."
  type        = string
}
