variable "cluster_name" {
  description = "The name of the Kubernetes cluster"
  type        = string
}

variable "cluster_version" {
  description = "The name of the Kubernetes cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "The endpoint of the Kubernetes cluster"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "The certificate authority data of the Kubernetes cluster"
  type        = string
}

variable "cluster_oidc_provider" {
  description = "The name of the OIDC provider noof the Kubernetes cluster"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "The ARN of the OIDC provider of the Kubernetes cluster"
  type        = string
}
