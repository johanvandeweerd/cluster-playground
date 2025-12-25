# Cluster playground

Sample project to create an EKS cluster with Terraform using EKS auto-mode and EKS capabilities. All resources are
created in their own VPC. The cluster also has the following services deployed:

- Karpenter (EKS auto-mode)
- CoreDNS (EKS auto-mode)
- Pod Identity (EKS auto-mode)
- metrics server (EKS addon)
- kube state metrics (EKS addon)
- node exporter (EKS addon)
- ArgoCD (EKS capabilities)
- AWS Managed Prometheus
- Prometheus scrapers (EKS managed)
- AWS Managed Grafana

# Bootstrapping

Run the following commands to bootstrap the project:

```shell
terraform init
terraform apply
```

Once the cluster is up and running, you can update your kubeconfig:

```shell
aws eks update-kubeconfig --name <PROJECT_NAME> --alias <PROJECT_NAME> 
```

Grafana is accessed using AWS Identity Center (SSO). The Identity Center instance of the organisation is used, which is
configured in the main account.
Add your user to the `GrafanaAdmin` group in AWS Identity Center (main account) and map that group in Grafana to the
`Admin` role.
Go to the AWS console, Grafana, All workspaces, your workspace, tab Authentication, Configure users and user groups. tab
Assigned user groups, button Action, Assign user group.
Go to tab Groups, select `GrafanaAdmin`, button Assign users and groups, tab Assigned user groups, select GrafanaAdmin,
button Action, make admin. Now you can log into Grafana using your Identity Center user.
Once in Grafana, add the Prometheus data source by going to Apps in the left menu, AWS Data Sources, Datasources, select
the service, region and check the AMP workspace followed by clicking Add 1 data source button.

# Cleanup

If something goes wrong, and you want to check if there are still some lingering resource, you can use the following
command to list them:

```shell
export AWS_REGION="eu-west-1"
export PROJECT_NAME="johan"
aws resource-groups search-resources --resource-query "{\"Type\":\"TAG_FILTERS_1_0\",\"Query\":\"{\\\"ResourceTypeFilters\\\":[\\\"AWS::AllSupported\\\"],\\\"TagFilters\\\":[{\\\"Key\\\":\\\"Project\\\",\\\"Values\\\":[\\\"${PROJECT_NAME}\\\"]}]}\"}"
```
