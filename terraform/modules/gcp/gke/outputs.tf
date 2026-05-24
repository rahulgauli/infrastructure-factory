output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.this.name
}

output "endpoint" {
  description = "Endpoint of the GKE control plane"
  value       = google_container_cluster.this.endpoint
}
