variable "team_name" {
  description = "Owning team"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "replication_destination_bucket_arn" {
  description = "ARN of the destination S3 bucket in another region for cross-region replication. When provided, replication is enabled."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to the bucket"
  type        = map(string)
  default     = {}
}
