output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "endpoint" {
  description = "Connection endpoint for the database"
  value       = aws_db_instance.this.endpoint
}
