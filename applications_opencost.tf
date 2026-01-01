module "opencost_iam_role" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name            = "${var.project_name}-opencost"
  description     = "TF: IAM role used by the opencost application"
  use_name_prefix = false

  trust_policy_conditions = [
    {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = [module.eks.cluster_arn]
    }
  ]

  associations = {
    opencost = {
      cluster_name    = module.eks.cluster_name
      namespace       = "opencost"
      service_account = "opencost"
    }
  }

  attach_custom_policy      = true
  custom_policy_description = "TF: Custom IAM policy for OpenCost application"
  policy_statements = [
    {
      sid    = "Prometheus"
      effect = "Allow"
      actions = [
        "aps:RemoteWrite",
        "aps:GetLabels",
        "aps:GetMetricMetadata",
        "aps:GetSeries",
        "aps:QueryMetrics"
      ]
      resources = [module.prometheus.workspace_arn]
    },
    # Something is missing from the two S3 statements below but haven't figured out what it is yet.
    # So for now allow everything on S3 :(
    {
      sid    = "AllowS3"
      effect = "Allow"
      actions = [
        "s3:*",
      ]
      resources = ["*"]
    },
    # {
    #   sid    = "AllowS3BucketAccess"
    #   effect = "Allow"
    #   actions = [
    #     "s3:ListBucket",
    #     "s3:GetBucketLocation"
    #   ]
    #   resources = [module.opencost_athena_s3_bucket.s3_bucket_arn]
    # },
    # {
    #   sid    = "AllowS3ObjectAccess"
    #   effect = "Allow"
    #   actions = [
    #     "s3:GetObject",
    #     "s3:PutObject"
    #   ]
    #   resources = ["${module.opencost_athena_s3_bucket.s3_bucket_arn}/*"]
    # },
    {
      sid    = "GlueTables"
      effect = "Allow"
      actions = [
        "glue:BatchGetTableOptimizer",
        "glue:GetTable*",
        "glue:GetPartitions",
      ]
      resources = [
        "arn:aws:glue:${data.aws_region.this.region}:${data.aws_caller_identity.this.account_id}:catalog",
        aws_glue_catalog_database.opencost.arn,
        "arn:aws:glue:${data.aws_region.this.region}:${data.aws_caller_identity.this.account_id}:table/${aws_glue_catalog_database.opencost.name}/*",
      ]
    },
    {
      sid    = "Athena"
      effect = "Allow"
      actions = [
        "athena:StartQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults",
      ]
      resources = [
        aws_athena_workgroup.opencost.arn,
        "${aws_athena_workgroup.opencost.arn}/*",
        "arn:aws:athena:${data.aws_region.this.region}:${data.aws_caller_identity.this.account_id}:query-execution/*"
      ]
    }
  ]
}

module "opencost_cur_s3_bucket" {
  providers = {
    aws = aws.us_east_1
  }

  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  bucket = "com-hootsuite-${var.project_name}-opencost-cur"
  region = "us-east-1"

  force_destroy     = true
  block_public_acls = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
  acl                      = "private"

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true
  attach_policy                         = true
  policy                                = data.aws_iam_policy_document.opencost_cur_s3_bucket_policy.json

  lifecycle_rule = [
    {
      id      = "auto-delete-old-objects"
      enabled = true
      expiration = {
        days = 7
      }
    },
  ]
}

data "aws_iam_policy_document" "opencost_cur_s3_bucket_policy" {
  statement {
    sid    = "AllowBillingReportsReadAclAndPolicy"
    effect = "Allow"
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
    ]
    principals {
      type = "Service"
      identifiers = [
        "billingreports.amazonaws.com",
        "delivery.logs.amazonaws.com",
      ]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.this.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cur:us-east-1:${data.aws_caller_identity.this.account_id}:definition/*",
        "arn:aws:logs:us-east-1:${data.aws_caller_identity.this.account_id}:*",
      ]
    }
    resources = [module.opencost_cur_s3_bucket.s3_bucket_arn]
  }
  statement {
    sid     = "AllowBillingReportsWriteReports"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type = "Service"
      identifiers = [
        "billingreports.amazonaws.com",
        "delivery.logs.amazonaws.com",
      ]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.this.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cur:us-east-1:${data.aws_caller_identity.this.account_id}:definition/*",
        "arn:aws:logs:us-east-1:${data.aws_caller_identity.this.account_id}:*",
      ]
    }
    resources = ["${module.opencost_cur_s3_bucket.s3_bucket_arn}/*"]
  }
}

resource "aws_cur_report_definition" "opencost" {
  provider = aws.us_east_1

  report_name                = "${var.project_name}-opencost-cur-report"
  time_unit                  = "HOURLY"
  format                     = "Parquet"
  compression                = "Parquet"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                  = module.opencost_cur_s3_bucket.s3_bucket_id
  s3_region                  = module.opencost_cur_s3_bucket.s3_bucket_region
  s3_prefix                  = "cur"
  additional_artifacts       = ["ATHENA"]
  report_versioning          = "OVERWRITE_REPORT"

  depends_on = [module.opencost_cur_s3_bucket.s3_bucket_policy]
}

module "opencost_s3_notifications_queue" {
  providers = {
    aws = aws.us_east_1
  }

  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 5.0"

  name = "${var.project_name}-opencost-s3-notifications"

  create_queue_policy = true
  queue_policy_statements = {
    AllowS3 = {
      effect  = "Allow"
      actions = ["sqs:SendMessage"]
      principals = [{
        type        = "Service"
        identifiers = ["s3.amazonaws.com"]
      }]
      condition = [{
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [module.opencost_cur_s3_bucket.s3_bucket_arn]
      }]
      resources = [module.opencost_s3_notifications_queue.queue_arn]
    }
  }

  create_dlq = true
}

resource "aws_s3_bucket_notification" "opencost" {
  provider = aws.us_east_1

  bucket = module.opencost_cur_s3_bucket.s3_bucket_id

  queue {
    queue_arn = module.opencost_s3_notifications_queue.queue_arn
    events = [
      "s3:ObjectCreated:*",
      "s3:ObjectRemoved:*"
    ]
  }

  depends_on = [module.opencost_s3_notifications_queue]
}

resource "aws_glue_crawler" "opencost" {
  name        = "${var.project_name}-opencost-cur"
  description = "TF: Glue crawler for OpenCost CUR reports used by project ${var.project_name}"

  role = module.opencost_glue_crawler_iam_role.arn

  database_name = aws_glue_catalog_database.opencost.name

  # Although the crawler is listening for S3 notifications on the SQS queue, we still need to schedule the crawler to
  # trigger. The crawler will however only crawl the changed files based on the S3 notifications in the SQS queue.
  schedule = "cron(0 * * * ? *)"

  s3_target {
    path                = "s3://${module.opencost_cur_s3_bucket.s3_bucket_id}/cur/"
    event_queue_arn     = module.opencost_s3_notifications_queue.queue_arn
    dlq_event_queue_arn = module.opencost_s3_notifications_queue.dead_letter_queue_arn
    exclusions          = ["**.json", "**.yml", "**.sql"]
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "DELETE_FROM_DATABASE"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVENT_MODE"
  }
}

module "opencost_glue_crawler_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name            = "${var.project_name}-opencost-glue-crawler"
  use_name_prefix = false
  description     = "TF: IAM role used by the OpenCost Glue Crawler for project ${var.project_name}"

  trust_policy_permissions = {
    glue = {
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["glue.amazonaws.com"]
      }]
    }
  }

  policies = {
    AWSGlueServiceRole = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  }

  create_inline_policy = true
  inline_policy_permissions = {
    CloudWatchLogs = {
      effect = "Allow"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = ["arn:aws:logs:*:*:*"]
    }
    Glue = {
      effect = "Allow"
      actions = [
        "glue:UpdateDatabase",
        "glue:UpdatePartition",
        "glue:CreateTable",
        "glue:UpdateTable",
        "glue:ImportCatalogToGlue",
      ]
      resources = ["*"]
    }
    S3 = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      resources = ["${module.opencost_cur_s3_bucket.s3_bucket_arn}/cur/*"]
    }
    SQS = {
      effect = "Allow"
      actions = [
        "sqs:DeleteMessage",
        "sqs:GetQueueUrl",
        "sqs:ListDeadLetterSourceQueues",
        "sqs:ReceiveMessage",
        "sqs:GetQueueAttributes",
        "sqs:ListQueueTags",
        "sqs:SetQueueAttributes",
        "sqs:PurgeQueue",
      ]
      resources = [
        module.opencost_s3_notifications_queue.queue_arn,
        module.opencost_s3_notifications_queue.dead_letter_queue_arn
      ]
    }
  }
}

resource "aws_glue_catalog_database" "opencost" {
  name        = "${var.project_name}-opencost"
  description = "TF: Glue catalog database for OpenCost used by project ${var.project_name}"
}

resource "aws_athena_workgroup" "opencost" {
  name        = "${var.project_name}-opencost"
  description = "TF: Athena workgroup for OpenCost used by project ${var.project_name}"

  force_destroy = true

  configuration {
    engine_version {
      selected_engine_version = "AUTO"
    }

    result_configuration {
      output_location = "s3://${module.opencost_athena_s3_bucket.s3_bucket_id}"
    }

    publish_cloudwatch_metrics_enabled = true
  }
}

module "opencost_athena_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  bucket = "com-hootsuite-${var.project_name}-opencost-athena"

  force_destroy     = true
  block_public_acls = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
  acl                      = "private"

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  lifecycle_rule = [
    {
      id      = "auto-delete-old-objects"
      enabled = true
      expiration = {
        days = 7
      }
    },
  ]
}
