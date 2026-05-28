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
    description = "Allow outbound within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
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
  identifier                        = substr(regexreplace("${local.name_prefix}-postgres", "[^a-z0-9-]", "-"), 0, 63)
  engine                            = "postgres"
  engine_version                    = "15.5"
  instance_class                    = var.instance_class
  allocated_storage                 = 20
  max_allocated_storage             = 100
  db_name                           = local.db_name
  username                          = "dbadmin"
  manage_master_user_password       = true
  storage_encrypted                 = true
  backup_retention_period           = 7
  deletion_protection               = true
  publicly_accessible               = false
  multi_az                          = false
  storage_type                      = "gp3"
  db_subnet_group_name              = aws_db_subnet_group.this.name
  vpc_security_group_ids            = [aws_security_group.this.id]
  skip_final_snapshot               = false
  final_snapshot_identifier         = substr(regexreplace("${local.name_prefix}-final", "[^a-z0-9-]", "-"), 0, 63)
  apply_immediately                 = true
  copy_tags_to_snapshot             = true
  auto_minor_version_upgrade        = true
  iam_database_authentication_enabled = true
  performance_insights_enabled      = true
  performance_insights_kms_key_id   = var.performance_insights_kms_key_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
  })
}
