variable "resource_group_name" {
  description = "Resource group name for Azure resources"
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
  description = "Logical region name"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "tags" {
  description = "Tags applied to Azure storage"
  type        = map(string)
  default     = {}
}
