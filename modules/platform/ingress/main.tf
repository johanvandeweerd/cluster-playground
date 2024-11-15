# ArgoCD applications
resource "kubectl_manifest" "application_aws_load_balancer_controller" {
  yaml_body = templatefile("${path.module}/chart/aws-load-balancer-controller/application.yaml", {
    name      = "aws-load-balancer-controller"
    namespace = "aws-load-balancer-controller"
    gitUrl    = var.git_url
    revision  = var.git_revision
    helmParameters = merge({ for key, value in data.aws_default_tags.this.tags : "tags.${key}" => value }, {
      "aws-load-balancer-controller.clusterName"                                                   = var.project_name
      "aws-load-balancer-controller.serviceAccount.annotations.eks\\\\.amazonaws\\\\.com/role-arn" = module.iam_role_aws_load_balancer_controller.iam_role_arn
      "aws-load-balancer-controller.vpcId"                                                         = data.aws_vpc.this.id
      "aws-load-balancer-controller.backendSecurityGroup"                                          = data.aws_security_group.this.id
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
      "targetGroupArn"              = module.nlb.target_groups["traefik"].arn
      "loadBalancerSecurityGroupId" = module.nlb.security_group_id
    })
  })
}

# IAM
module "iam_role_aws_load_balancer_controller" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name            = "${var.project_name}-aws-load-balancer-controller"
  description     = "TF: IAM role used by AWS Load Balancer controller for IRSA."
  use_name_prefix = "false"

  attach_aws_lb_controller_targetgroup_binding_only_policy = true
  aws_lb_controller_targetgroup_arns                       = ["arn:aws:elasticloadbalancing:*:*:targetgroup/eks*"]
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.project_name
  namespace       = "aws-load-balancer-controller"
  service_account = "aws-load-balancer-controller"
  role_arn        = module.iam_role_aws_load_balancer_controller.iam_role_arn
}

# Certificate
module "acm" {
  source = "terraform-aws-modules/acm/aws"

  domain_name = "*.${var.project_name}.${var.hosted_zone}"
  zone_id     = aws_route53_zone.this.zone_id

  validation_method = "DNS"

  wait_for_validation = true
}

# Load Balancer
module "nlb" {
  source = "terraform-aws-modules/alb/aws"

  name    = var.project_name
  vpc_id  = data.aws_vpc.this.id
  subnets = data.aws_subnets.public.ids

  load_balancer_type         = "network"
  enable_deletion_protection = false

  security_group_name            = "${var.project_name}-nlb"
  security_group_use_name_prefix = false
  security_group_description     = "TF: Security group used by the NLB for the ${var.project_name} cluster."
  security_group_ingress_rules = {
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_tags = {
    Name = "${var.project_name}-nlb"
  }

  listeners = {
    https = {
      port            = 443
      protocol        = "TLS"
      certificate_arn = module.acm.acm_certificate_arn
      forward = {
        target_group_key = "traefik"
      }
    }
  }

  target_groups = {
    traefik = {
      name_prefix       = "eks"
      protocol          = "TLS"
      port              = 443
      target_type       = "ip"
      create_attachment = false
    }
  }
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

resource "aws_route53_record" "star" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "*"
  type    = "A"

  alias {
    zone_id                = module.nlb.zone_id
    name                   = module.nlb.dns_name
    evaluate_target_health = false
  }
}
