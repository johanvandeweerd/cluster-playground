variable "project_name" {
  description = "Name to use for the VPC, EKS cluster, etc and to use as prefix to name resources."
  type        = string
}

variable "git_url" {
  description = "The Git URL used in the Argpcd application manifests."
  type        = string
}

variable "git_revision" {
  description = "The Git revision used in the Argpcd application manifests."
  type        = string
}

variable "hosted_zone" {
  description = "The hosted zone under which the project name is used as a subdomain for this project."
  type        = string
}
