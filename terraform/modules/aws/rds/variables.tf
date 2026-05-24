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

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allowed_cidr" {
  description = "Trusted CIDR block allowed to access PostgreSQL"
  type        = string
  default     = "10.0.0.0/8"
}

variable "tags" {
  description = "Common tags applied to the database"
  type        = map(string)
  default     = {}
}
