output "network_id" {
  description = "Identifier of the VPC network"
  value       = google_compute_network.this.id
}

output "subnetwork_id" {
  description = "Identifier of the private subnetwork"
  value       = google_compute_subnetwork.private.id
}
