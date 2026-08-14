# terraform-aws-lambda

Terraform module to create an AWS Lambda function with its execution role, log group, triggers and permissions.

## Design

**One function per module call.** Unlike the map-driven modules in this portfolio, a Lambda function carries enough per-function configuration — packaging, VPC, layers, event sources, concurrency, its own IAM role — that a map would make the interface harder to read than calling the module twice.

**All packaging types in one module.** `package_type` is a single argument; everything else is identical between zip and container functions. Splitting them would duplicate the role, log group, triggers and permissions across two modules. Preconditions validate that each packaging type receives the inputs it needs.

## Features

- **Four ways to ship code**: a local directory zipped by the module, an existing zip, an S3 object, or an ECR image (with CMD/ENTRYPOINT overrides)
- **Execution role created in-module**, with logging permissions scoped to the function's own log group rather than the broad `AWSLambdaBasicExecutionRole`; VPC and X-Ray policies attach automatically when those features are enabled
- **Log group managed by the module**, so retention and KMS encryption apply from the first invocation — a log group Lambda creates on its own never expires
- Event source mappings for SQS, DynamoDB streams and Kinesis, with event filtering, batching windows, scaling limits and partial batch responses
- Invoke permissions for AWS services, optional alias, VPC config, dead letter target, environment variable encryption and X-Ray tracing
- **arm64 by default** (Graviton: same performance at lower cost)
- Preconditions that catch packaging mistakes at plan time instead of during the apply

## Usage

```hcl
module "lambda" {
  source = "github.com/orlando-mt/terraform-aws-lambda?ref=v1.0.0"

  function_name = "my-processor"

  source_path = "${path.module}/src"
  handler     = "handler.lambda_handler"
  runtime     = "python3.12"

  memory_size = 512
  timeout     = 60

  environment_variables = {
    STAGE = "prod"
  }

  inline_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = module.sqs.queue_arns["jobs"]
      }
    ]
  }

  event_source_mappings = {
    jobs = {
      event_source_arn        = module.sqs.queue_arns["jobs"]
      batch_size              = 10
      function_response_types = ["ReportBatchItemFailures"]
    }
  }

  tags = {
    Project   = "my-project"
    ManagedBy = "terraform"
  }
}
```

### Container image

```hcl
module "lambda" {
  source = "github.com/orlando-mt/terraform-aws-lambda?ref=v1.0.0"

  function_name = "my-processor"
  package_type  = "Image"
  image_uri     = "${module.ecr.repository_url}:v1.2.3"

  memory_size = 1024
}
```

## Notes

- **Partial batch responses:** with SQS, a failing message normally makes the whole batch visible again. Setting `function_response_types = ["ReportBatchItemFailures"]` and returning the failed message IDs retries only those — worth enabling on any SQS consumer.
- **Timeout vs visibility timeout:** the queue's visibility timeout must exceed the function timeout, otherwise messages are redelivered while still being processed.
- **VPC functions** need `security_group_ids` alongside `subnet_ids`, and reach AWS services through NAT or VPC endpoints — see [terraform-aws-vpc-endpoint](https://github.com/orlando-mt/terraform-aws-vpc-endpoint).

## Examples

- [Complete](./examples/complete)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| aws | >= 5.0 |
| archive | >= 2.4 |

## Resources

| Name | Type |
|------|------|
| aws_lambda_function.this | resource |
| aws_lambda_alias.this | resource |
| aws_lambda_event_source_mapping.this | resource |
| aws_lambda_permission.this | resource |
| aws_cloudwatch_log_group.this | resource |
| aws_iam_role.this | resource |
| aws_iam_policy.logging | resource |
| aws_iam_role_policy.inline | resource |
| aws_iam_role_policy_attachment.* | resource |
| archive_file.this | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| function_name | Name of the function | `string` | n/a | yes |
| description | Function description | `string` | `null` | no |
| package_type | Zip or Image | `string` | `"Zip"` | no |
| source_path | Directory to package | `string` | `null` | no |
| package_excludes | Paths excluded when packaging | `list(string)` | `[]` | no |
| local_zip_path / source_code_hash | Existing zip | `string` | `null` | no |
| s3_bucket / s3_key / s3_object_version | Package in S3 | `string` | `null` | no |
| image_uri | ECR image URI | `string` | `null` | no |
| image_command / image_entry_point / image_working_directory | Container overrides | `list/string` | `[]` / `null` | no |
| handler / runtime | Zip packaging settings | `string` | `null` | no |
| layers | Layer ARNs | `list(string)` | `[]` | no |
| architectures | `["arm64"]` or `["x86_64"]` | `list(string)` | `["arm64"]` | no |
| memory_size | Memory in MB (128-10240) | `number` | `256` | no |
| timeout | Timeout in seconds (1-900) | `number` | `30` | no |
| ephemeral_storage_size | /tmp size in MB | `number` | `512` | no |
| reserved_concurrent_executions | Reserved concurrency | `number` | `-1` | no |
| publish | Publish a version per change | `bool` | `false` | no |
| environment_variables | Environment variables | `map(string)` | `{}` | no |
| environment_kms_key_arn | KMS key for env vars | `string` | `null` | no |
| tracing_mode | Active or PassThrough | `string` | `"Active"` | no |
| dead_letter_target_arn | DLQ for async invocations | `string` | `null` | no |
| subnet_ids / security_group_ids | VPC configuration | `list(string)` | `[]` | no |
| role_arn | Existing execution role | `string` | `null` (created) | no |
| role_name | Name of the created role | `string` | `null` (derived) | no |
| permissions_boundary | Boundary for the created role | `string` | `null` | no |
| inline_policy | Function permissions (JSON or HCL) | `any` | `null` | no |
| additional_policy_arns | Policies to attach | `list(string)` | `[]` | no |
| event_source_mappings | SQS/DynamoDB/Kinesis triggers | `map(object)` | `{}` | no |
| invoke_permissions | Service invoke permissions | `map(object)` | `{}` | no |
| create_alias / alias_name | Alias configuration | `bool` / `string` | `false` / `"live"` | no |
| log_retention_days | Log retention | `number` | `14` | no |
| log_group_kms_key_id | KMS key for the log group | `string` | `null` | no |
| tags | Tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| function_name / function_arn / qualified_arn | Function identity |
| invoke_arn | Invoke ARN for API Gateway |
| version | Latest published version |
| alias_arn / alias_invoke_arn | Alias details |
| role_arn / role_name | Execution role |
| log_group_name / log_group_arn | Log group |
<!-- END_TF_DOCS -->

## License

MIT. See [LICENSE](./LICENSE).
