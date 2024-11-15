#!/bin/zsh

terraform init
terraform apply -target module.network -auto-approve
terraform apply -target module.cluster -auto-approve
terraform apply -target module.platform -auto-approve
terraform apply -target module.product -auto-approve
