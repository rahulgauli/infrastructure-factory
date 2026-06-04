data "aws_caller_identity" "current" {}

locals {
  bucket_name      = substr(regexreplace(lower("${var.team_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"), "[^a-z0-9-]", "-"), 0, 63)
  log_bucket_name  = substr(regexreplace(lower("${var.team_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-logs"), "[^a-z0-9-]", "-"), 0, 63)
  iam_name_prefix  = substr(regexreplace(lower("${var.team_name}-${var.environment}"), "[^a-z0-9_+=,.@-]", "-"), 0, 32)
  common_tags = merge(var.tags, {
    team_name   = var.team_name
    environment = var.environment
    managed_by  = "infrastructure-factory"
  })
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  tags = merge(local.common_tags, {
    Name = local.bucket_name
  })
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "transition-old-objects"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket ${local.bucket_name}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.bucket_name}-key"
  })
}

resource "aws_s3_bucket" "logs" {
  bucket = local.log_bucket_name

  tags = merge(local.common_tags, {
    Name    = local.log_bucket_name
    Purpose = "access-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "this" {
  bucket = aws_s3_bucket.this.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}

resource "aws_sns_topic" "s3_notifications" {
  name              = "${local.bucket_name}-notifications"
  kms_master_key_id = aws_kms_key.s3.id

  tags = local.common_tags
}

resource "aws_s3_bucket_notification" "this" {
  bucket = aws_s3_bucket.this.id

  topic {
    topic_arn = aws_sns_topic.s3_notifications.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

data "aws_iam_policy_document" "s3_replication_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "s3_replication" {
  count = var.replication_destination_bucket_arn != null ? 1 : 0

  name_prefix        = "${local.iam_name_prefix}-s3-repl-"
  assume_role_policy = data.aws_iam_policy_document.s3_replication_assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "s3_replication" {
  statement {
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = ["${coalesce(var.replication_destination_bucket_arn, "arn:aws:s3:::placeholder")}/*"]
  }
}

resource "aws_iam_role_policy" "s3_replication" {
  count = var.replication_destination_bucket_arn != null ? 1 : 0

  name   = "s3-replication"
  role   = aws_iam_role.s3_replication[0].id
  policy = data.aws_iam_policy_document.s3_replication.json
}

resource "aws_s3_bucket_replication_configuration" "this" {
  count = var.replication_destination_bucket_arn != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  role   = aws_iam_role.s3_replication[0].arn

  rule {
    id     = "full-replication"
    status = "Enabled"

    destination {
      bucket        = var.replication_destination_bucket_arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
