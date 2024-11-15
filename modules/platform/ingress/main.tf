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
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name        = "${var.project_name}-aws-load-balancer-controller"
  role_description = "TF: IAM role used by AWS Load Balancer controller for IRSA."

  oidc_providers = {
    (var.project_name) = {
      provider                   = var.kubernetes_oidc_provider
      provider_arn               = var.kubernetes_oidc_provider_arn
      namespace_service_accounts = ["aws-load-balancer-controller:aws-load-balancer-controller"]
    }
  }

  role_policy_arns = {
    "aws-load-balancer-controller" = aws_iam_policy.aws_load_balancer_controller.arn
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.project_name}-aws-load-balancer-controller"
  description = "TF: IAM policy with the necessary permissions for AWS Load Balancer controller."

  policy = data.aws_iam_policy_document.aws_load_balancer_controller.json
}

data "aws_iam_policy_document" "aws_load_balancer_controller" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "ec2:Vpc"
      values = [
        "arn:aws:ec2:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:vpc/${data.aws_vpc.this.id}"
      ]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"
      values = [
        "CreateTargetGroup",
        "CreateLoadBalancer"
      ]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]
    resources = ["*"]
  }
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
