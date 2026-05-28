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

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt EKS secrets"
  type        = string
}

variable "tags" {
  description = "Common tags applied to the cluster"
  type        = map(string)
  default     = {}
}
