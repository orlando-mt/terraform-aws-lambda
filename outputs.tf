output "function_name" {
  description = "Name of the function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the function"
  value       = aws_lambda_function.this.arn
}

output "qualified_arn" {
  description = "ARN with the published version qualifier"
  value       = aws_lambda_function.this.qualified_arn
}

output "invoke_arn" {
  description = "Invoke ARN, for API Gateway integrations"
  value       = aws_lambda_function.this.invoke_arn
}

output "version" {
  description = "Latest published version"
  value       = aws_lambda_function.this.version
}

output "alias_arn" {
  description = "ARN of the alias (null when not created)"
  value       = var.create_alias ? aws_lambda_alias.this[0].arn : null
}

output "alias_invoke_arn" {
  description = "Invoke ARN of the alias (null when not created)"
  value       = var.create_alias ? aws_lambda_alias.this[0].invoke_arn : null
}

output "role_arn" {
  description = "ARN of the execution role"
  value       = local.role_arn
}

output "role_name" {
  description = "Name of the created execution role (null when an existing role is used)"
  value       = local.create_role ? aws_iam_role.this[0].name : null
}

output "log_group_name" {
  description = "CloudWatch log group of the function"
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.this.arn
}
