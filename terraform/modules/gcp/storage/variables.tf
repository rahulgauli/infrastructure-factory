variable "project_id" {
  description = "GCP project identifier"
  type        = string
}

variable "team_name" {
  description = "Owning team"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "tags" {
  description = "Labels applied to the bucket"
  type        = map(string)
  default     = {}
}
