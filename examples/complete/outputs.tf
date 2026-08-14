output "function_arn" {
  description = "ARN of the function"
  value       = module.lambda.function_arn
}

output "role_arn" {
  description = "Execution role created for the function"
  value       = module.lambda.role_arn
}

output "log_group_name" {
  description = "CloudWatch log group"
  value       = module.lambda.log_group_name
}
