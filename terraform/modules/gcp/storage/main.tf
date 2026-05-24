locals {
  bucket_name = substr(regexreplace(lower("${var.team_name}-${var.environment}-storage"), "[^a-z0-9-]", "-"), 0, 63)
  labels = merge(var.tags, {
    team_name   = var.team_name
    environment = var.environment
    managed_by  = "infrastructure-factory"
  })
}

resource "google_kms_key_ring" "this" {
  project  = var.project_id
  name     = "${local.bucket_name}-kr"
  location = var.region
}

resource "google_kms_crypto_key" "this" {
  name            = "${local.bucket_name}-key"
  key_ring        = google_kms_key_ring.this.id
  rotation_period = "7776000s"
}

resource "google_storage_bucket" "this" {
  name                        = local.bucket_name
  project                     = var.project_id
  location                    = upper(var.region)
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = local.labels

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.this.id
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }

    condition {
      age = 365
    }
  }
}
