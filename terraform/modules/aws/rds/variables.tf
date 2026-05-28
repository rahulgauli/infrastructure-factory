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

variable "db_parameter_group_family" {
  description = "The DB parameter group family (e.g. postgres15, postgres16)"
  type        = string
  default     = "postgres15"
}

variable "tags" {
  description = "Common tags applied to the database"
  type        = map(string)
  default     = {}
}
