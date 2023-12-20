terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "hackathon-dec-2023"
      Team        = "Awesome"
      Contributor = var.contributor
      Petname     = random_pet.for_robert.id
    }
  }
}
