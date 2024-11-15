# Cluster playground

![](https://media1.giphy.com/media/Ppk0LL1mCFa36/giphy.gif?cid=ecf05e47e64brpzy6dlpfnsfybbrfjw1geci1wk42ac4cfar&ep=v1_gifs_search&rid=giphy.gif&ct=g)

# Setup

Create a `variables.auto.tfvars` file with the following content.

```hcl
project_name = "<PROJECT_NAME>"
git_url      = "git@github.com:<ORGANIZATION>/cluster-playground"
git_revision = "<GIT_BRANCH>"
```

```shell
```

Run the following command to update your kubeconfig when the cluster is up and running:

```
aws eks update-kubeconfig --name <PROJECT_NAME> --alias <PROJECT_NAME> 
```

# Argocd

To access Argocd, port-forward the Argocd server to a local port.

```
kubectl port-forward -n argocd service/argo-cd-argocd-server 8000:443
```

Browse to [https://localhost:8000](https://localhost:8000) and login with username `admin`.  
Get the password from the`argocd-initial-admin-secret` using the following command:

```
kubectl get secret -n argocd argocd-initial-admin-secret -ojson | jq -r '.data.password' | base64 -d 
```

## Git SSH key (optional)

If you want Argocd to use a private Github repostiories, you need to add the necessary SSH keys to Secrets Manager.

```
vi ssh-key-github-com
aws secretsmanager create-secret --name "${TF_VAR_project_name}/argocd/ssh-key-github-com" --description "Secrets used by Argocd" --secret-string "$(cat ssh-key-github-com)"
rm ssh-key-github-com
```

# Teardown

### Destroy

```shell
terraform apply -target module.platform -destroy
kubectl delete poddisruptionbudget -A --all
kubectl delete nodepool --all
kubectl delete nodeclaims --all
kubectl delete ec2nodeclass --all
terraform apply -target module.cluster -destroy
terraform apply -target module.network -destroy
```

You can use following AWS CLI command to get an idea of the resources that still exist.

```
export AWS_REGION="<SOME_AWS_REGION>"
aws resource-groups search-resources  --resource-query "{\"Type\":\"TAG_FILTERS_1_0\",\"Query\":\"{\\\"ResourceTypeFilters\\\":[\\\"AWS::AllSupported\\\"],\\\"TagFilters\\\":[{\\\"Key\\\":\\\"Project\\\",\\\"Values\\\":[\\\"${TF_VAR_project_name}\\\"]}]}\"}"
```
