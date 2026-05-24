locals {
  sink_name = substr(regexreplace(lower("${var.team_name}-${var.environment}-audit-sink"), "[^a-z0-9-]", "-"), 0, 60)
  labels = merge(var.tags, {
    team_name   = var.team_name
    environment = var.environment
    managed_by  = "infrastructure-factory"
    security    = "baseline"
  })
}

resource "google_storage_bucket" "audit_logs" {
  name                        = substr(regexreplace(lower("${var.project_id}-${var.environment}-audit"), "[^a-z0-9-]", "-"), 0, 63)
  project                     = var.project_id
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  labels                      = local.labels

  versioning {
    enabled = true
  }
}

resource "google_project_iam_audit_config" "project_audit" {
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_organization_policy" "restrict_public_ips" {
  count      = var.organization_id != "" ? 1 : 0
  org_id     = var.organization_id
  constraint = "constraints/compute.vmExternalIpAccess"

  boolean_policy {
    enforced = true
  }
}

resource "google_logging_project_sink" "centralized" {
  project                = var.project_id
  name                   = local.sink_name
  destination            = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"
  unique_writer_identity = true
  filter                 = "severity>=NOTICE"
}

resource "google_project_service" "securitycenter" {
  project            = var.project_id
  service            = "securitycenter.googleapis.com"
  disable_on_destroy = false
}
