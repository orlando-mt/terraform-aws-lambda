# Changelog

## [1.0.0] - 2026-08-14

### Added
- Initial release: Lambda function supporting all packaging types — local
  directory zipped by the module, existing zip, S3 object, or ECR image
- Execution role created in-module with least-privilege logging scoped to
  the function's own log group, plus VPC and X-Ray policies when needed
- Log group managed by the module so retention and encryption apply from
  the first invocation
- Event source mappings (SQS, DynamoDB streams, Kinesis) with filtering,
  partial batch responses and scaling limits
- Invoke permissions, optional alias, VPC config, dead letter target,
  X-Ray tracing and arm64 by default
- Preconditions validating packaging inputs at plan time
