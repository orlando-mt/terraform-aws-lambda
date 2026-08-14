# ---------------------------------------------------------------------------
# Execution role. Created in-module unless an existing role ARN is supplied:
# every Lambda needs one, and its baseline permissions are not a choice.
# ---------------------------------------------------------------------------

locals {
  create_role = var.role_arn == null
  role_arn    = local.create_role ? aws_iam_role.this[0].arn : var.role_arn
}

resource "aws_iam_role" "this" {
  count = local.create_role ? 1 : 0

  name        = coalesce(var.role_name, "${var.function_name}-role")
  description = "Execution role for the ${var.function_name} function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  permissions_boundary = var.permissions_boundary

  tags = var.tags
}

# Write to the function's own log group only, rather than the broad
# AWSLambdaBasicExecutionRole managed policy.
resource "aws_iam_policy" "logging" {
  count = local.create_role ? 1 : 0

  name        = coalesce(var.role_name, "${var.function_name}-role")
  description = "Write logs for the ${var.function_name} function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.this.arn}:*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  count = local.create_role ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = aws_iam_policy.logging[0].arn
}

# ENI management, required whenever the function runs inside a VPC
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count = local.create_role && length(var.subnet_ids) > 0 ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray" {
  count = local.create_role && var.tracing_mode == "Active" ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSXRayDaemonWriteAccess"
}

# Inline policy for the function's own permissions
resource "aws_iam_role_policy" "inline" {
  count = local.create_role && var.inline_policy != null ? 1 : 0

  name   = "${var.function_name}-policy"
  role   = aws_iam_role.this[0].id
  policy = try(tostring(var.inline_policy), jsonencode(var.inline_policy))
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = local.create_role ? toset(var.additional_policy_arns) : []

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}
