# AIOS Agent — Aiden Infra (composition)

Single Terraform entry for **dual IaC** PoC: [`aios-agent-cfn-author`](../aios-agent-cfn-author/) (CloudFormation intent, drift, compliance) plus optional [`aios-agent-terraform-bot`](../aios-agent-terraform-bot/) (Terraform module quality).

Does **not** create a second StackGen MCP integration — pass `existing_stackgen_mcp_integration_name` for the tenant singleton when enabling terraform-bot.

## Usage

```hcl
module "foundation_bedrock" {
  source = "../aios-foundation-bedrock"
  # ...
}

module "aiden_infra" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-aiden-infra?ref=main"

  model_names = module.foundation_bedrock.model_names
  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  target_repository_full_name = "org/infra-templates"
  github_secret_id            = module.github_integration.secret_id
  aws_secret_id               = module.aws_integration.secret_id

  enable_terraform_bot                   = true
  stackgen_token_secret_id               = module.stackgen_openapi_secret.id

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

See [`docs/enterprise-deployment-profile.md`](../../docs/enterprise-deployment-profile.md) for when to use this module vs `aios-agent-selfhosted-infra` alone.

## Outputs

| Output | Description |
|--------|-------------|
| `cfn_author` | Nested CFN author credentials and workflow map |
| `terraform_bot` | Bot agent/workflow names when enabled |
| `aiden_infra_workflow_names` | Merged workflow name map |
| `webhook_trigger_endpoint` | Guild webhook trigger URL |
