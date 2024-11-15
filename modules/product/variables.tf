variable "project_name" {
  description = "Name to use for the VPC, EKS cluster, etc and to use as prefix to name resources."
  type        = string
}

variable "git_url" {
  description = "The Git URL used in the Argocd application manifest"
  type        = string
}

variable "git_revision" {
  description = "The Git revision used in the Argocd application manifest"
  type        = string
}
