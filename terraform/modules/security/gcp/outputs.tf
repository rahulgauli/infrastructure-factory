output "logging_sink_name" {
  description = "Name of the centralized logging sink"
  value       = google_logging_project_sink.centralized.name
}

output "audit_config_id" {
  description = "Identifier of the project audit configuration"
  value       = google_project_iam_audit_config.project_audit.id
}
