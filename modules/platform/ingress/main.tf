# ArgoCD applications
resource "kubectl_manifest" "application_aws_load_balancer_controller" {
  yaml_body = templatefile("${path.module}/chart/aws-load-balancer-controller/application.yaml", {
    name      = "aws-load-balancer-controller"
    namespace = "aws-load-balancer-controller"
    gitUrl    = var.git_url
    revision  = var.git_revision
    helmParameters = merge({ for key, value in data.aws_default_tags.this.tags : "tags.${key}" => value }, {
      "aws-load-balancer-controller.vpcId"       = data.aws_vpc.this.id
      "aws-load-balancer-controller.clusterName" = var.project_name
    })
  })
}

resource "kubectl_manifest" "application_traefik" {
  yaml_body = templatefile("${path.module}/chart/traefik/application.yaml", {
    name      = "traefik"
    namespace = "traefik"
    gitUrl    = var.git_url
    revision  = var.git_revision
    helmParameters = merge({ for key, value in data.aws_default_tags.this.tags : "tags.${key}" => value }, {
      "targetGroupArn" = module.alb.target_groups["traefik"].arn
    })
  })
}

# IAM
module "iam_role_aws_load_balancer_controller" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name            = "${var.project_name}-aws-load-balancer-controller"
  description     = "TF: IAM role used by AWS Load Balancer controller for IRSA."
  use_name_prefix = "false"

  attach_aws_lb_controller_targetgroup_binding_only_policy = true
  aws_lb_controller_targetgroup_arns                       = values(module.alb.target_groups)[*].arn
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.project_name
  namespace       = "aws-load-balancer-controller"
  service_account = "aws-load-balancer-controller"
  role_arn        = module.iam_role_aws_load_balancer_controller.iam_role_arn
}

# Preshared key
resource "random_uuid" "psk" {
}

# Cloudfront
module "certificate_cloudfront" {
  providers = {
    aws = aws.us_east_1
  }

  source  = "terraform-aws-modules/acm/aws"
  version = "~> 2.0"

  domain_name = "*.${var.project_name}.${var.hosted_zone}"
  zone_id     = aws_route53_zone.this.zone_id

  validation_method = "DNS"

  wait_for_validation = true
}

module "cdn" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 1.0"

  aliases = ["*.${var.project_name}.${var.hosted_zone}"]

  comment         = "TF: Cloudfont distribution in front of the ${var.project_name} EKS cluster."
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_All"

  origin = {
    eks = {
      origin_id   = "eks"
      domain_name = aws_route53_record.alb.fqdn
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
      custom_header = [{
        name  = "X-Aperture-PSK-Auth"
        value = random_uuid.psk.result
      }]
    }
  }

  default_cache_behavior = {
    target_origin_id       = "eks"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["POST", "HEAD", "PATCH", "DELETE", "PUT", "GET", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true

    use_forwarded_values = false

    cache_policy_id          = data.aws_cloudfront_cache_policy.this.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.this.id
  }

  viewer_certificate = {
    acm_certificate_arn      = module.certificate_cloudfront.this_acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Load Balancer
module "certificate_load_balancer" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 2.0"

  domain_name = "alb.${var.project_name}.${var.hosted_zone}"
  zone_id     = aws_route53_zone.this.zone_id

  validation_method = "DNS"

  wait_for_validation = true
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name    = var.project_name
  vpc_id  = data.aws_vpc.this.id
  subnets = data.aws_subnets.public.ids

  load_balancer_type         = "application"
  enable_deletion_protection = false
  preserve_host_header       = true
  xff_header_processing_mode = "append" // "preserve"

  security_group_name            = "${var.project_name}-alb"
  security_group_use_name_prefix = false
  security_group_description     = "TF: Security group used by the ALB for the ${var.project_name} cluster."
  security_group_ingress_rules = {
    https = {
      from_port      = 443
      to_port        = 443
      ip_protocol    = "tcp"
      description    = "TF: HTTPS web traffic"
      prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront.id
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_tags = {
    Name = "${var.project_name}-alb"
  }

  listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = module.certificate_load_balancer.this_acm_certificate_arn
      fixed_response = {
        content_type = "text/plain"
        message_body = "Unauthorized"
        status_code  = "401"
      }
      rules = {
        default = {
          actions = [{
            forward = {
              target_group_key = "traefik"
            }
          }]
          conditions = [{
            http_header = {
              http_header_name = "X-Aperture-PSK-Auth"
              values           = [random_uuid.psk.result]
            }
          }]
        }
      }
    }
  }

  target_groups = {
    traefik = {
      name_prefix       = "eks"
      protocol          = "HTTPS"
      port              = 443
      target_type       = "ip"
      create_attachment = false
      health_check = {
        enabled  = true
        path     = "/ping"
        port     = "9000"
        protocol = "HTTP"
      }
    }
  }
}

# Security group
resource "aws_security_group_rule" "allow_alb_to_worker_nodes_on_8443" {
  security_group_id        = data.aws_security_group.this.id
  description              = "TF: Allow ALB to communicate with worker nodes on port 8443"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 8443
  to_port                  = 8443
  source_security_group_id = module.alb.security_group_id
}

resource "aws_security_group_rule" "allow_alb_to_worker_nodes_on_9000" {
  security_group_id        = data.aws_security_group.this.id
  description              = "TF: Allow ALB to do Traefik health check with worker nodes on port 9000"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 9000
  to_port                  = 9000
  source_security_group_id = module.alb.security_group_id
}

# DNS
resource "aws_route53_record" "ns" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.project_name
  type    = "NS"
  ttl     = 172800
  records = aws_route53_zone.this.name_servers
}

resource "aws_route53_zone" "this" {
  name = "${var.project_name}.${var.hosted_zone}"
}

resource "aws_route53_record" "alb" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "alb"
  type    = "A"

  alias {
    zone_id                = module.alb.zone_id
    name                   = module.alb.dns_name
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "star" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "*"
  type    = "A"

  alias {
    zone_id                = module.cdn.this_cloudfront_distribution_hosted_zone_id
    name                   = module.cdn.this_cloudfront_distribution_domain_name
    evaluate_target_health = false
  }
}
