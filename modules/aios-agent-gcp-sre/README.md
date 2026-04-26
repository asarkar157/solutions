# AIOS Agent — GCP SRE

GCP cloud operations SRE agent with GKE diagnostics, Cloud SQL health checks, security audit, and cost analysis workflows.

## Usage

```hcl
module "gcp_sre" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-gcp-sre"

  model_names      = module.foundation.model_names
  policy_ids       = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  integration_name = "gcp-production"
}
```

## What It Creates

- 1 Agent with `gcp-tool-governance` policy
- 4 Runbook SOPs (GKE diagnostics, security audit, cost analysis, Cloud SQL health)
- 2 Workflows (gcp-unified-audit, gke-incident-response)
