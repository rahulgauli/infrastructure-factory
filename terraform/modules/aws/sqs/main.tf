locals {
  queue_name = substr(
    regexreplace("${var.team_name}-${var.environment}-sqs", "[^a-zA-Z0-9_-]", "-"),
    0,
    80,
  )
  dlq_name = "${local.queue_name}-dlq"
  common_tags = merge(var.tags, {
    team_name   = var.team_name
    environment = var.environment
    managed_by  = "infrastructure-factory"
  })
}

resource "aws_sqs_queue" "dlq" {
  name                      = local.dlq_name
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"

  tags = merge(local.common_tags, {
    Name = local.dlq_name
  })
}

resource "aws_sqs_queue" "this" {
  name                       = local.queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  kms_master_key_id          = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(local.common_tags, {
    Name = local.queue_name
  })
}
