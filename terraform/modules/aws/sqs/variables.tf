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

variable "visibility_timeout_seconds" {
  description = "Visibility timeout for messages in seconds"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Number of seconds to retain a message (max 1209600 = 14 days)"
  type        = number
  default     = 86400
}

variable "receive_wait_time_seconds" {
  description = "Wait time for long polling in seconds (0 disables long polling)"
  type        = number
  default     = 20
}

variable "max_receive_count" {
  description = "Maximum number of receives before a message is sent to the dead-letter queue"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Common tags applied to SQS resources"
  type        = map(string)
  default     = {}
}
