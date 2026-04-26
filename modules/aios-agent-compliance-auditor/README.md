# AIOS Agent — Compliance Auditor

Automated compliance auditing agent for SOC2, GDPR, HIPAA, and ISO 27001 frameworks with evidence collection.

## Usage

```hcl
module "compliance" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-compliance-auditor"

  model_names = module.foundation.model_names
  policy_ids  = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
    data_risk_pii = module.policies.policy_ids.data_risk_pii
  }

  integration_names = {
    aws    = module.aws_integration.integration_name
    github = module.github_integration.integration_name
  }
}
```

## What It Creates

- 1 Agent with `compliance-data-access` policy
- 4 Runbook SOPs (SOC2 access review, change mgmt, GDPR data mapping, audit log analysis)
- 1 Workflow (compliance-assessment)
