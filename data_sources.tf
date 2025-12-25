data "aws_region" "this" {
}

data "aws_availability_zones" "this" {
}

data "aws_caller_identity" "this" {
}

data "aws_route53_zone" "this" {
  name = var.hosted_zone
}

data "aws_ssoadmin_instances" "this" {
  provider = aws.main
}

data "aws_identitystore_group" "argocd_admin" {
  provider = aws.main

  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "ArgocdAdmin"
    }
  }
}

data "aws_identitystore_group" "grafana_admin" {
  provider = aws.main

  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "GrafanaAdmin"
    }
  }
}

data "aws_prometheus_default_scraper_configuration" "this" {
}
