variable "project_name" {
  description = "Name to use for the VPC, EKS cluster, etc and to use as prefix to name resources."
  type        = string
}

variable "kubernetes_endpoint" {
  description = "The endpoint of the Kubernetes cluster"
  type        = string
}

variable "kubernetes_oidc_provider" {
  description = "The OIDC provider of the Kubernetes cluster"
  type        = string
}

variable "kubernetes_oidc_provider_arn" {
  description = "The ARN of the OIDC provider of the Kubernetes cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "The list of IDs of the private subnets to use."
  type        = list(string)
}

variable "create_spot_service_linked_role" {
  description = "Whether to create the Spot service linked role."
  type        = bool
}
