variable "region" {
  description = "AWS region"
  type        = string
}

variable "function_name" {
  description = "Name of the function"
  type        = string
}

variable "description" {
  description = "Description of the function"
  type        = string
  default     = null
}

variable "handler" {
  description = "Function handler"
  type        = string
}

variable "runtime" {
  description = "Runtime identifier"
  type        = string
}

variable "architectures" {
  description = "Instruction set"
  type        = list(string)
  default     = ["arm64"]
}

variable "memory_size" {
  description = "Memory in MB"
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Timeout in seconds"
  type        = number
  default     = 30
}

variable "environment_variables" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "inline_policy" {
  description = "Inline policy for the function's permissions"
  type        = any
  default     = null
}

variable "event_source_mappings" {
  description = "Event source mappings"
  type = map(object({
    event_source_arn                   = string
    batch_size                         = optional(number)
    maximum_batching_window_in_seconds = optional(number)
    starting_position                  = optional(string)
    maximum_concurrency                = optional(number)
    function_response_types            = optional(list(string))
    filter_patterns                    = optional(list(string))
    enabled                            = optional(bool, true)
  }))
  default = {}
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
