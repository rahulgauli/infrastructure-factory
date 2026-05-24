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

variable "organization_id" {
  description = "Optional GCP organization ID used for org-level policy assignment"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Labels applied to security resources"
  type        = map(string)
  default     = {}
}
