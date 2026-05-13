# AIOS Agent — SRE

Production-ready SRE agent team for incident response, change correlation, auto-remediation, risk assessment, and incident command.

## Usage

```hcl
module "sre_agents" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-sre"

  model_names = module.foundation.model_names
  policy_ids  = module.policies.policy_ids
  # Plan-time flags so optional policy attachments use a known Terraform count (required when policy IDs are unknown until apply).
  policy_create_flags = {
    sre_remediation          = module.policies.policy_create_flags.sre_remediation
    prod_write_gate          = module.policies.policy_create_flags.prod_write_gate
    tier0_service_protection = module.policies.policy_create_flags.tier0_service_protection
    blast_radius_limit       = module.policies.policy_create_flags.blast_radius_limit
    freeze_window            = module.policies.policy_create_flags.freeze_window
    data_risk_pii            = module.policies.policy_create_flags.data_risk_pii
    post_action_verification = module.policies.policy_create_flags.post_action_verification
  }

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
| `sg_evidence_checklist` | 4 | Post-incident, change, security, and quick-triage evidence templates |
| `sg_workflow` | 2 | Full + quick triage incident response |

## Outputs

| Name | Description |
|------|-------------|
| `agent_names` | Map of all SRE agent names |
| `workflow_names` | Map of workflow names |
| `evidence_checklist_names` | Map of evidence checklist names (for SDLC / other modules) |
