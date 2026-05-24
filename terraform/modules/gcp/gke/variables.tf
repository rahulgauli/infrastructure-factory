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

variable "node_machine_type" {
  description = "Machine type for the default node pool"
  type        = string
  default     = "e2-standard-4"
}

variable "tags" {
  description = "Labels applied to the cluster"
  type        = map(string)
  default     = {}
}
