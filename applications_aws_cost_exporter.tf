resource "aws_iam_role" "aws_cost_exporter" {
  name               = "${var.project_name}-aws-cost-exporter"
  description        = "TF: IAM role used by the aws-cost-exporter application"
  assume_role_policy = data.aws_iam_policy_document.aws_cost_exporter_assume_policy.json
}

data "aws_iam_policy_document" "aws_cost_exporter_assume_policy" {
  statement {
    sid    = "AllowEksPodIdentity"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role_policy" "aws_cost_exporter" {
  role   = aws_iam_role.aws_cost_exporter.name
  name   = "AWSCostExporter"
  policy = data.aws_iam_policy_document.aws_cost_exporter.json
}

data "aws_iam_policy_document" "aws_cost_exporter" {
  statement {
    sid       = "AllowGetCostAndUsageData"
    effect    = "Allow"
    actions   = ["ce:GetCostAndUsage"]
    resources = ["*"]
  }
}
