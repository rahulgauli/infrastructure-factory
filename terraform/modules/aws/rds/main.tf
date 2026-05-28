data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  name_prefix = "${var.team_name}-${var.environment}"
  db_name     = substr(regexreplace(lower("${var.team_name}${var.environment}"), "[^a-z0-9]", ""), 0, 16)
  common_tags = merge(var.tags, {
    team_name   = var.team_name
    environment = var.environment
    managed_by  = "infrastructure-factory"
  })
}

resource "aws_security_group" "this" {
  name_prefix = "${local.name_prefix}-rds-"
  description = "Security group for RDS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow PostgreSQL from trusted CIDR"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

data "aws_iam_policy_document" "rds_monitoring_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name_prefix        = "${local.name_prefix}-rds-mon-"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${local.name_prefix}-pg-"
  family      = var.db_parameter_group_family

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "0"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg"
  })
}

resource "aws_db_subnet_group" "this" {
  name       = substr(regexreplace("${local.name_prefix}-db-subnets", "[^a-z0-9-]", "-"), 0, 255)
  subnet_ids = data.aws_subnets.default.ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnets"
  })
}

resource "aws_db_instance" "this" {
  identifier                   = substr(regexreplace("${local.name_prefix}-postgres", "[^a-z0-9-]", "-"), 0, 63)
  engine                       = "postgres"
  engine_version               = "15.5"
  instance_class               = var.instance_class
  allocated_storage            = 20
  max_allocated_storage        = 100
  db_name                      = local.db_name
  username                     = "dbadmin"
  manage_master_user_password  = true
  storage_encrypted            = true
  backup_retention_period      = 7
  deletion_protection          = true
  publicly_accessible          = false
  multi_az                     = true
  storage_type                 = "gp3"
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.this.id]
  parameter_group_name         = aws_db_parameter_group.this.name
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  skip_final_snapshot          = false
  final_snapshot_identifier    = substr(regexreplace("${local.name_prefix}-final", "[^a-z0-9-]", "-"), 0, 63)
  apply_immediately            = true
  copy_tags_to_snapshot        = true
  performance_insights_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
  })
}
