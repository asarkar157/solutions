# AIOS Agent — SRE

Production-ready SRE agent team for incident response, change correlation, auto-remediation, risk assessment, and incident command.

## Usage

```hcl
module "sre_agents" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-sre"

  model_names = module.foundation.model_names
  policy_ids  = module.policies.policy_ids

  integration_names = {
    grafana = module.grafana_integration.integration_name
    slack   = module.slack_integration.integration_name
  }
}
```

## What It Creates

| Resource Type | Count | Description |
|---|---|---|
| `sg_agent` | 5 | triage, change-correlation, auto-remediation, risk-posture, incident-commander |
| `sg_agent_budget` | 5 | Daily spending limits per agent |
| `sg_agent_policy_attachment` | 15+ | Guardrail policy bindings |
| `sg_runbook_sop` | 9 | Operational runbooks |
| `sg_remediation_pattern` | 8 | Remediation playbooks |
| `sg_evidence_checklist` | 3 | Post-incident evidence templates |
| `sg_workflow` | 2 | Full + quick triage incident response |

## Outputs

| Name | Description |
|------|-------------|
| `agent_names` | Map of all SRE agent names |
| `workflow_names` | Map of workflow names |
