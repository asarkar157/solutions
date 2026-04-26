# AIOS Agent — Multi-Cloud Cost Optimizer

FinOps agent for multi-cloud cost optimization: idle resource detection, rightsizing, commitment optimization, and anomaly detection.

## Usage

```hcl
module "cost_optimizer" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-cost-optimizer"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    aws   = module.aws_integration.integration_name
    azure = module.azure_integration.integration_name
    slack = module.slack_integration.integration_name
  }
}
```

## What It Creates

- 1 Agent (cost-optimizer)
- 4 Runbook SOPs (idle scan, rightsizing, savings plan review, anomaly detection)
- 1 Workflow (finops-review) with 5-stage fan-out/fan-in DAG
