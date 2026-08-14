# Complete example

Deploys a Python function packaged from [`src/`](./src) that consumes an SQS
queue:

- arm64 (Graviton), 512 MB, 60s timeout
- Execution role created by the module, with an inline policy granting
  access to the queue
- Event source mapping with batching and `ReportBatchItemFailures`, so a
  single bad message does not force the whole batch to be retried

Replace the queue ARN in [`terraform.tfvars`](./terraform.tfvars) with your
own — it can come from the `queue_arns` output of
[terraform-aws-sqs](https://github.com/orlando-mt/terraform-aws-sqs).

## Usage

```bash
terraform init
terraform plan
terraform apply
```
