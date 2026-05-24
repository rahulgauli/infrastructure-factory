output "bucket_name" {
  description = "Name of the storage bucket"
  value       = google_storage_bucket.this.name
}

output "kms_key_id" {
  description = "Crypto key protecting the bucket"
  value       = google_kms_crypto_key.this.id
}
