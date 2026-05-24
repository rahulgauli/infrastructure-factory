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

variable "subnet_cidr" {
  description = "CIDR range for the private subnet"
  type        = string
  default     = "10.20.0.0/24"
}

variable "tags" {
  description = "Labels applied to the network"
  type        = map(string)
  default     = {}
}
