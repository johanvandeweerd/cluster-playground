#!/bin/zsh

echo "######################################"
echo "### Removing product resources ###"
echo "######################################"
terraform apply -target module.product -destroy -auto-approve
echo ""

echo "#######################################"
echo "### Removing platform resources ###"
echo "#######################################"
terraform apply -target module.platform -destroy -auto-approve
echo ""

echo "##################################"
echo "### Removing EC2 instances ###"
echo "##################################"
kubectl delete poddisruptionbudget -A --all
kubectl delete nodepool --all
kubectl delete nodeclaims --all
# Wait until all nodeclaims are deleted
while [[ $(kubectl get nodeclaims --no-headers | wc -l) -ne 0 ]]; do
  echo "Waiting for nodeclaims to be deleted..."
  sleep 5
done
kubectl delete ec2nodeclass --all
echo ""

echo "######################################"
echo "### Removing cluster resources ###"
echo "######################################"
terraform apply -target module.cluster -destroy -auto-approve
echo ""

echo "######################################"
echo "### Removing network resources ###"
echo "######################################"
terraform apply -target module.network -destroy -auto-approve
