provider "aws" {
  region = var.region
}

module "lambda" {
  source = "../../"

  function_name = var.function_name
  description   = var.description

  # Zip packaging: the module builds the archive from this directory
  source_path = "${path.module}/src"
  handler     = var.handler
  runtime     = var.runtime

  architectures = var.architectures
  memory_size   = var.memory_size
  timeout       = var.timeout

  environment_variables = var.environment_variables

  # Permissions the function needs beyond writing its own logs
  inline_policy = var.inline_policy

  event_source_mappings = var.event_source_mappings

  log_retention_days = var.log_retention_days

  tags = var.tags
}
