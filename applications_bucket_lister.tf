resource "aws_iam_role" "bucket_lister" {
  name               = "${var.project_name}-bucket-lister"
  description        = "TF: IAM role used by the bucket-lister application"
  assume_role_policy = data.aws_iam_policy_document.bucket_lister_assume_policy.json
}

data "aws_iam_policy_document" "bucket_lister_assume_policy" {
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

resource "aws_iam_role_policy" "s3" {
  role   = aws_iam_role.bucket_lister.name
  name   = "S3"
  policy = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "s3" {
  statement {
    sid    = "AllowListS3Buckets"
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
    ]
    resources = ["*"]
  }
}
