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

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.29"
}

variable "node_vm_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "tags" {
  description = "Tags applied to AKS resources"
  type        = map(string)
  default     = {}
}

variable "automatic_channel_upgrade" {
  description = "Upgrade channel for AKS (none, patch, rapid, stable, node-image)"
  type        = string
  default     = "patch"
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDR ranges authorized to access the AKS API server"
  type        = list(string)
  default     = []
}

variable "disk_encryption_set_id" {
  description = "Resource ID of the disk encryption set used to encrypt AKS node OS disks"
  type        = string
  default     = null
}
