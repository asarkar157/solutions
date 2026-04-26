# AIOS Agent — AWS SRE

AWS cloud operations SRE agent with K8s diagnostics, security audit, cost analysis, and tagging compliance workflows.

## Usage

```hcl
module "aws_sre" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-aws-sre"

  model_names      = module.foundation.model_names
  policy_ids       = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  integration_name = module.aws_integration.integration_name
}
```

## What It Creates

- 1 Agent (aws-sre) with own `aws-tool-governance` policy
- 4 Runbook SOPs (K8s diagnostics, security audit, cost analysis, tag sanity)
- 2 Workflows (k8s-monitoring, aws-unified-audit)
