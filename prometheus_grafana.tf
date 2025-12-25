module "prometheus" {
  source  = "terraform-aws-modules/managed-service-prometheus/aws"
  version = "~> 4.0"

  workspace_alias = var.project_name

  retention_period_in_days               = 7
  cloudwatch_log_group_retention_in_days = 7

  create_alert_manager = false

  tags = {
    AMPAgentlessScraper = ""
  }
}

resource "aws_prometheus_scraper" "this" {
  alias = "general"

  source {
    eks {
      cluster_arn = module.eks.cluster_arn
      subnet_ids  = module.vpc.private_subnets
    }
  }

  destination {
    amp {
      workspace_arn = module.prometheus.workspace_arn
    }
  }

  scrape_configuration = data.aws_prometheus_default_scraper_configuration.this.configuration
}

module "grafana" {
  source  = "terraform-aws-modules/managed-service-grafana/aws"
  version = "~> 2.0"

  name              = var.project_name
  description       = "TF: AWS Managed Grafana service for ${var.project_name}"
  associate_license = false
  data_sources      = ["PROMETHEUS"]

  iam_role_name            = "${var.project_name}-grafana"
  use_iam_role_name_prefix = false

  security_group_name            = "${var.project_name}-grafana"
  security_group_use_name_prefix = false
  security_group_rules = {
    outbound = {
      type        = "egress"
      description = "TF: Allow all outbound traffic"
      protocol    = "all"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  security_group_tags = {
    Name = "${var.project_name}-grafana"
  }

  vpc_configuration = {
    subnet_ids = module.vpc.private_subnets
  }

  configuration = jsonencode({
    unifiedAlerting = {
      enabled = false
    }
    plugins = {
      pluginAdminEnabled = true
    }
  })

  role_associations = {
    admin = {
      role      = "ADMIN"
      group_ids = [data.aws_identitystore_group.grafana_admin.id]
    }
  }
}
