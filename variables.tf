variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "description" {
  description = "Description of the function"
  type        = string
  default     = null
}

# --- Packaging -------------------------------------------------------------

variable "package_type" {
  description = "Packaging type: Zip or Image"
  type        = string
  default     = "Zip"

  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "package_type must be Zip or Image."
  }
}

variable "source_path" {
  description = "Local directory to package into a zip. Mutually exclusive with local_zip_path and the S3 inputs"
  type        = string
  default     = null
}

variable "package_excludes" {
  description = "Paths excluded when packaging source_path"
  type        = list(string)
  default     = []
}

variable "local_zip_path" {
  description = "Path to an existing zip file to deploy"
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Base64 SHA256 of the zip, required with local_zip_path to detect changes"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket holding the deployment package"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the deployment package"
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "Version of the S3 object"
  type        = string
  default     = null
}

variable "image_uri" {
  description = "ECR image URI (required when package_type is Image)"
  type        = string
  default     = null
}

variable "image_command" {
  description = "Override for the container CMD"
  type        = list(string)
  default     = []
}

variable "image_entry_point" {
  description = "Override for the container ENTRYPOINT"
  type        = list(string)
  default     = []
}

variable "image_working_directory" {
  description = "Override for the container working directory"
  type        = string
  default     = null
}

variable "handler" {
  description = "Function handler (Zip packaging only)"
  type        = string
  default     = null
}

variable "runtime" {
  description = "Runtime identifier, e.g. python3.12, nodejs20.x, java21 (Zip packaging only)"
  type        = string
  default     = null
}

variable "layers" {
  description = "Layer ARNs to attach (Zip packaging only)"
  type        = list(string)
  default     = []
}

# --- Runtime configuration -------------------------------------------------

variable "architectures" {
  description = "Instruction set: [\"arm64\"] (Graviton, cheaper) or [\"x86_64\"]"
  type        = list(string)
  default     = ["arm64"]

  validation {
    condition     = length(var.architectures) == 1 && contains(["arm64", "x86_64"], var.architectures[0])
    error_message = "architectures must be exactly one of [\"arm64\"] or [\"x86_64\"]."
  }
}

variable "memory_size" {
  description = "Memory in MB (128-10240). CPU scales with memory"
  type        = number
  default     = 256

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Timeout in seconds (1-900)"
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "ephemeral_storage_size" {
  description = "Size of /tmp in MB (512-10240)"
  type        = number
  default     = 512
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrency (-1 for unreserved). Set it to cap a function's share of the account limit"
  type        = number
  default     = -1
}

variable "publish" {
  description = "Publish a new version on each change"
  type        = bool
  default     = false
}

variable "environment_variables" {
  description = "Environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "environment_kms_key_arn" {
  description = "KMS key ARN to encrypt environment variables at rest"
  type        = string
  default     = null
}

variable "tracing_mode" {
  description = "X-Ray tracing: Active or PassThrough"
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "tracing_mode must be Active or PassThrough."
  }
}

variable "dead_letter_target_arn" {
  description = "SQS queue or SNS topic ARN for failed asynchronous invocations"
  type        = string
  default     = null
}

# --- Networking ------------------------------------------------------------

variable "subnet_ids" {
  description = "Private subnets to run the function in. Leave empty to run outside a VPC"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security groups for the function's ENIs (required when subnet_ids is set)"
  type        = list(string)
  default     = []
}

# --- IAM -------------------------------------------------------------------

variable "role_arn" {
  description = "Existing execution role ARN. When null, the module creates the role"
  type        = string
  default     = null
}

variable "role_name" {
  description = "Name of the created execution role (defaults to <function_name>-role)"
  type        = string
  default     = null
}

variable "permissions_boundary" {
  description = "Permissions boundary ARN for the created role"
  type        = string
  default     = null
}

variable "inline_policy" {
  description = "Inline policy for the function's own permissions, as JSON string or HCL object"
  type        = any
  default     = null
}

variable "additional_policy_arns" {
  description = "Existing policy ARNs to attach to the created role"
  type        = list(string)
  default     = []
}

# --- Triggers --------------------------------------------------------------

variable "event_source_mappings" {
  description = <<-EOT
    Map of event source mappings (SQS, DynamoDB streams, Kinesis). Each entry:
      - event_source_arn (required)
      - batch_size, maximum_batching_window_in_seconds (optional)
      - starting_position (optional): required for streams, not for SQS
      - maximum_concurrency (optional): SQS scaling limit
      - function_response_types (optional): ["ReportBatchItemFailures"] to
        enable partial batch responses
      - filter_patterns (optional): list of JSON filter patterns
      - enabled (optional, true)
  EOT
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

variable "invoke_permissions" {
  description = "Map of statement IDs to invoke permissions for AWS services (principal, source_arn, source_account)"
  type = map(object({
    principal      = string
    source_arn     = optional(string)
    source_account = optional(string)
  }))
  default = {}
}

# --- Alias and logging -----------------------------------------------------

variable "create_alias" {
  description = "Create an alias pointing at the published version"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Name of the alias"
  type        = string
  default     = "live"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "log_group_kms_key_id" {
  description = "KMS key ARN to encrypt the log group"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
