#!/bin/zsh

terraform apply -target module.product -destroy -auto-approve
terraform apply -target module.platform -destroy -auto-approve
kubectl delete poddisruptionbudget -A --all
kubectl delete nodepool --all
kubectl delete nodeclaims --all
kubectl delete ec2nodeclass --all
terraform apply -target module.cluster -destroy -auto-approve
terraform apply -target module.network -destroy -auto-approve
