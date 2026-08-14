locals {
  is_image  = var.package_type == "Image"
  build_zip = var.package_type == "Zip" && var.source_path != null

  filename         = local.build_zip ? data.archive_file.this[0].output_path : var.local_zip_path
  source_code_hash = local.build_zip ? data.archive_file.this[0].output_base64sha256 : var.source_code_hash
}

# ---------------------------------------------------------------------------
# Package the source directory when source_path is given
# ---------------------------------------------------------------------------

data "archive_file" "this" {
  count = local.build_zip ? 1 : 0

  type        = "zip"
  source_dir  = var.source_path
  output_path = "${path.module}/.build/${var.function_name}.zip"
  excludes    = var.package_excludes
}

# ---------------------------------------------------------------------------
# Log group, created ahead of the function so retention and encryption apply
# from the first invocation (Lambda would otherwise create it unmanaged)
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  # checkov:skip=CKV_AWS_338:Retention is configurable via log_retention_days; the 14-day default balances cost for application logs. Set 365+ where compliance requires it.
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_group_kms_key_id

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Function
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  lifecycle {
    precondition {
      condition     = var.package_type != "Image" || var.image_uri != null
      error_message = "image_uri is required when package_type is Image."
    }

    precondition {
      condition     = var.package_type != "Zip" || (var.handler != null && var.runtime != null)
      error_message = "handler and runtime are required when package_type is Zip."
    }

    precondition {
      condition = var.package_type != "Zip" || (
        var.source_path != null || var.local_zip_path != null || (var.s3_bucket != null && var.s3_key != null)
      )
      error_message = "Zip packaging needs one of: source_path, local_zip_path, or s3_bucket + s3_key."
    }

    precondition {
      condition     = length(var.subnet_ids) == 0 || length(var.security_group_ids) > 0
      error_message = "security_group_ids is required when the function runs in a VPC."
    }
  }

  function_name = var.function_name
  description   = var.description
  role          = local.role_arn

  package_type = var.package_type

  # Zip packaging
  filename          = local.is_image ? null : local.filename
  s3_bucket         = local.is_image ? null : var.s3_bucket
  s3_key            = local.is_image ? null : var.s3_key
  s3_object_version = local.is_image ? null : var.s3_object_version
  source_code_hash  = local.is_image ? null : local.source_code_hash
  handler           = local.is_image ? null : var.handler
  runtime           = local.is_image ? null : var.runtime
  layers            = local.is_image ? null : var.layers

  # Container packaging
  image_uri = local.is_image ? var.image_uri : null

  dynamic "image_config" {
    for_each = local.is_image && (length(var.image_command) > 0 || length(var.image_entry_point) > 0 || var.image_working_directory != null) ? [1] : []
    content {
      command           = var.image_command
      entry_point       = var.image_entry_point
      working_directory = var.image_working_directory
    }
  }

  architectures                  = var.architectures
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions
  publish                        = var.publish

  kms_key_arn = var.environment_kms_key_arn

  ephemeral_storage {
    size = var.ephemeral_storage_size
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  tracing_config {
    mode = var.tracing_mode
  }

  tags = merge(var.tags, { Name = var.function_name })

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.basic_execution
  ]
}

# ---------------------------------------------------------------------------
# Alias (optional), for stable ARNs across versions
# ---------------------------------------------------------------------------

resource "aws_lambda_alias" "this" {
  count = var.create_alias ? 1 : 0

  name             = var.alias_name
  function_name    = aws_lambda_function.this.function_name
  function_version = var.publish ? aws_lambda_function.this.version : "$LATEST"
}

# ---------------------------------------------------------------------------
# Event source mappings (SQS, DynamoDB streams, Kinesis)
# ---------------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "this" {
  for_each = var.event_source_mappings

  function_name    = var.create_alias ? aws_lambda_alias.this[0].arn : aws_lambda_function.this.arn
  event_source_arn = each.value.event_source_arn
  enabled          = each.value.enabled

  batch_size                         = each.value.batch_size
  maximum_batching_window_in_seconds = each.value.maximum_batching_window_in_seconds
  starting_position                  = each.value.starting_position
  function_response_types            = each.value.function_response_types

  dynamic "scaling_config" {
    for_each = each.value.maximum_concurrency != null ? [1] : []
    content {
      maximum_concurrency = each.value.maximum_concurrency
    }
  }

  dynamic "filter_criteria" {
    for_each = each.value.filter_patterns != null ? [1] : []
    content {
      dynamic "filter" {
        for_each = each.value.filter_patterns
        content {
          pattern = filter.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Invoke permissions for AWS services (API Gateway, EventBridge, SNS, ...)
# ---------------------------------------------------------------------------

resource "aws_lambda_permission" "this" {
  for_each = var.invoke_permissions

  statement_id   = each.key
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.function_name
  qualifier      = var.create_alias ? aws_lambda_alias.this[0].name : null
  principal      = each.value.principal
  source_arn     = each.value.source_arn
  source_account = each.value.source_account
}
