region        = "us-east-1"
function_name = "example-processor"
description   = "Processes messages from the jobs queue"

handler = "handler.lambda_handler"
runtime = "python3.12"

# Graviton: same performance, lower cost
architectures = ["arm64"]
memory_size   = 512
timeout       = 60

environment_variables = {
  STAGE     = "dev"
  LOG_LEVEL = "INFO"
}

# Read the queue the function consumes from
inline_policy = <<-POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        "Resource": "arn:aws:sqs:us-east-1:123456789012:example-jobs"
      }
    ]
  }
POLICY

# Consume the SQS queue, reporting per-message failures so only the failed
# ones are retried instead of the whole batch
event_source_mappings = {
  jobs = {
    event_source_arn                   = "arn:aws:sqs:us-east-1:123456789012:example-jobs"
    batch_size                         = 10
    maximum_batching_window_in_seconds = 5
    maximum_concurrency                = 10
    function_response_types            = ["ReportBatchItemFailures"]
  }
}

log_retention_days = 14

tags = {
  Project   = "example"
  ManagedBy = "terraform"
}
