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

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "allowed_cidr" {
  description = "Trusted CIDR block allowed for SSH access"
  type        = string
  default     = "10.0.0.0/8"
}

variable "tags" {
  description = "Common tags applied to the instance"
  type        = map(string)
  default     = {}
}
