# Complete AIOS Stack Example

This example deploys the full AIOS stack, mirroring the production deployment in `terraform/guild/main.tf`. It demonstrates how all module layers compose together.

## Prerequisites

- StackGen platform with Guild enabled
- LLM API keys (OpenAI + Anthropic minimum)
- AWS IAM role for SRE operations
- Grafana instance with API token
- Slack bot token

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```
