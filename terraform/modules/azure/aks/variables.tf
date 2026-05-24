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
