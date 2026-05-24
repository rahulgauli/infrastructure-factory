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

variable "address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.30.0.0/16"
}

variable "subnet_prefix" {
  description = "Subnet prefix for the primary subnet"
  type        = string
  default     = "10.30.1.0/24"
}

variable "tags" {
  description = "Tags applied to Azure network resources"
  type        = map(string)
  default     = {}
}
