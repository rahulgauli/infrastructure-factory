locals {
  cluster_name = substr(regexreplace(lower("${var.team_name}-${var.environment}-gke"), "[^a-z0-9-]", "-"), 0, 40)
  labels = merge(var.tags, {
    team_name   = var.team_name
    environment = var.environment
    managed_by  = "infrastructure-factory"
  })
}

resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = substr(regexreplace(lower("${var.team_name}-${var.environment}-nodes"), "[^a-z0-9-]", "-"), 0, 30)
  display_name = "${var.team_name} ${var.environment} node pool"
}

resource "google_container_cluster" "this" {
  name                     = local.cluster_name
  project                  = var.project_id
  location                 = var.region
  network                  = "default"
  subnetwork               = "default"
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {}

  release_channel {
    channel = "REGULAR"
  }

  enable_shielded_nodes = true
  resource_labels       = local.labels
}

resource "google_container_node_pool" "system" {
  name       = "${local.cluster_name}-system"
  cluster    = google_container_cluster.this.name
  project    = var.project_id
  location   = var.region
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = local.labels
  }
}
