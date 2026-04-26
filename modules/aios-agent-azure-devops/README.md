# AIOS Agent — Azure DevOps SRE

Azure data pipeline SRE agent with ClickHouse diagnostics, storage queue inspection, and function health checks.

## Usage

```hcl
module "azure_devops" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-azure-devops"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    azure = module.azure_integration.integration_name
    slack = module.slack_integration.integration_name
  }
}
```
