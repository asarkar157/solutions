# AIOS Agent — Multi-Cloud Resource Janitor

Detects cloud resources that have been **inactive for ≥ `inactivity_days`** (default 30 days) — Lambda functions never invoked, S3 buckets not modified, unattached EBS / disks, stopped compute, idle EIPs / NAT gateways — and offers a **HITL-gated cleanup workflow** that tag-and-quarantines first and only deletes after a configurable dwell window.

## Usage

```hcl
module "resource_janitor" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-resource-janitor"

  # aios-foundation exposes model_names as list(string) — pass it through.
  # To hand-pick: model_names = [module.foundation.model_names_by_provider.claude_sonnet]
  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    aws   = module.aws_integration.integration_name
    slack = module.slack_integration.integration_name
    # azure = module.azure_integration.integration_name
    # gcp   = module.gcp_integration.integration_name
  }

  inactivity_days       = 30
  cleanup_dwell_days    = 7
  max_resources_per_run = 25
  cleanup_dollar_cap    = 1000
}

# Periodic detection — runs every Monday at 08:00 UTC
module "resource_janitor_schedules" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-schedules"

  target_type = "workflow"
  target_name = module.resource_janitor.workflow_names.detection

  schedules = [
    {
      name       = "weekly-unused-resource-sweep"
      expression = "0 8 * * 1"
      action     = "Run the detection workflow across all attached cloud integrations and post a per-team summary to Slack. Read-only — no quarantine in this run."
    },
  ]
}
```

## What It Creates

- **1 agent**: `resource-janitor` (AWS / Azure / GCP / Slack integrations as configured)
- **4 runbook SOPs**: `lambda-inactivity-scan`, `s3-stale-bucket-scan`, `idle-compute-extended-scan`, `safe-cleanup-procedure`
- **1 evidence checklist**: `unused-resource-cleanup-evidence`
- **2 workflows**:
  - `unused-resource-detection` — read-only, scheduled
  - `unused-resource-cleanup` — destructive, HITL-gated via `dangerous-ops`

## How cleanup is kept safe

1. **Detection is read-only.** It can be scheduled freely.
2. **Cleanup is two-phase.** First run quarantines (tags + renames + Slack-notifies the owner). Second run, only after `cleanup_dwell_days` have elapsed, deletes.
3. **Dangerous-ops policy is required.** Every deletion goes through the `dangerous-ops` policy attachment so the operator must approve.
4. **Caps protect blast radius.** `max_resources_per_run` (default 25) and `cleanup_dollar_cap` (default $1000) stop the workflow early.
5. **Resources tagged `aios:cleanup:exempt=true` or `do-not-delete=true` are always skipped.**

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `model_names` | yes | — | `list(string)` of registered model names in priority order; passed straight to `sg_agent.model_names` |
| `policy_ids` | yes | — | Must include `dangerous_ops` |
| `integration_names` | yes | `{}` | At minimum `aws`; `azure`, `gcp`, `slack` extend the scan |
| `inactivity_days` | no | `30` | Threshold for treating a resource as unused |
| `cleanup_dwell_days` | no | `7` | Days a resource must remain in quarantine before deletion |
| `max_resources_per_run` | no | `25` | Hard cap per cleanup execution |
| `cleanup_dollar_cap` | no | `1000` | Stop cleanup early once estimated savings hit this USD figure |
| `agent_budget` | no | `10` | Daily $ budget for the agent |
| `workflow_skill_refs` | no | `{}` | Optional `skill_refs` overrides per `<workflow>::<stage>` |

## Outputs

| Name | Description |
|------|-------------|
| `agent_name` | Guild name of the agent |
| `workflow_names` | `{ detection, cleanup }` — pass to `aios-agent-schedules` |
| `runbook_names` | All registered runbook SOP names |
| `evidence_checklist_name` | Name of the cleanup workflow's evidence checklist |
