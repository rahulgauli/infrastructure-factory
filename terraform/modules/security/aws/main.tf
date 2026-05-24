data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

locals {
  name_prefix = "${var.team_name}-${var.environment}"
  common_tags = merge(var.tags, {
    team_name   = var.team_name
    environment = var.environment
    managed_by  = "infrastructure-factory"
    security    = "baseline"
  })
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = substr(regexreplace(lower("${local.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"), "[^a-z0-9-]", "-"), 0, 63)

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudtrail"
  })
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_policy" "security_baseline" {
  name        = substr(regexreplace("${local.name_prefix}-security-baseline", "[^a-zA-Z0-9+=,.@_-]", "-"), 0, 128)
  description = "Deny dangerous security-impacting actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyTrailTampering"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "config:DeleteConfigurationRecorder",
          "kms:ScheduleKeyDeletion"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "config" {
  name = substr(regexreplace("${local.name_prefix}-config-role", "[^a-zA-Z0-9+=,.@_-]", "-"), 0, 64)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${local.name_prefix}-config"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${local.name_prefix}-config-channel"
  s3_bucket_name = aws_s3_bucket.cloudtrail.bucket

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_cloudtrail" "audit_trail" {
  name                          = "${local.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  tags = local.common_tags
}

resource "aws_security_group" "baseline_sg" {
  name_prefix = "${local.name_prefix}-baseline-"
  description = "Egress-only baseline security group"
  vpc_id      = data.aws_vpc.default.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-baseline"
  })
}

resource "aws_resourcegroups_group" "baseline" {
  name = substr(regexreplace("${local.name_prefix}-security-group", "[^a-zA-Z0-9+=,.@_-]", "-"), 0, 300)

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "environment"
          Values = [var.environment]
        }
      ]
    })
  }

  tags = merge(local.common_tags, {
    logging    = "enabled"
    encryption = "required"
  })
}
