resource "aws_eks_capability" "ack" {
  cluster_name              = module.eks.cluster_name
  capability_name           = "ack"
  type                      = "ACK"
  role_arn                  = aws_eks_access_policy_association.ack.principal_arn
  delete_propagation_policy = "RETAIN"
}

# We need to manually create the access entry and policy association for ACK to work properly. Otherwise the creation of the capability fails with the following error. Not sure why this is 🤷‍♂️
# InvalidParameterException: The trust policy for the provided role is invalid. The policy must include sts:AssumeRole and sts:TagSession actions granting access to the AWS service capabilities.eks.amazonaws.com
resource "aws_eks_access_entry" "ack" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.ack_iam_role.arn
}

resource "aws_eks_access_policy_association" "ack" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.ack.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSACKPolicy"
  access_scope {
    type = "cluster"
  }
}

module "ack_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name            = "${var.project_name}-ack"
  use_name_prefix = false
  description     = "TF: IAM role used by AWS Controller for Kubernetes."

  trust_policy_permissions = {
    EksCapabilities = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
      principals = [{
        type        = "Service"
        identifiers = ["capabilities.eks.amazonaws.com"]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    AllowCreatePodIdentityAssociations = {
      effect = "Allow"
      actions = [
        "eks:ListPodIdentityAssociations",
        "eks:CreatePodIdentityAssociation",
      ]
      resources = [module.eks.cluster_arn]
    }
    AllowDeleteUpdatePodIdentityAssociations = {
      effect = "Allow"
      actions = [
        "eks:DeletePodIdentityAssociation",
        "eks:DescribePodIdentityAssociation",
        "eks:TagResource",
        "eks:UpdatePodIdentityAssociation",
      ]
      resources = ["arn:aws:eks:${data.aws_region.this.id}:${data.aws_caller_identity.this.account_id}:podidentityassociation/${module.eks.cluster_name}/*"]
    }
    AllowPassAndGetRole = {
      effect = "Allow"
      actions = [
        "iam:PassRole",
        "iam:GetRole",
      ]
      resources = ["*"]
    }
    AllowReadEksCluster = {
      effect = "Allow"
      actions = [
        "eks:DescribeCluster",
      ]
      resources = [module.eks.cluster_arn]
    }
  }
}
