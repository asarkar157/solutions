# AIOS Agent — Azure SaaS SRE

SRE with remediation for single-tenant Azure SaaS: PagerDuty alert ingestion, deterministic ingest filtering, Datadog + Azure auto-investigation, Confluence runbook lookup, and Azure Automation remediation.

## Usage

```hcl
module "azure_saas_sre" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-azure-saas-sre?ref=main"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    sre_remediation = module.policies.policy_ids.sre_remediation
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  confluence_space_key = "SRE"

  datadog_api_key = var.datadog_api_key
  datadog_app_key = var.datadog_app_key

  pagerduty_api_token = var.pagerduty_api_token

  confluence_base_url  = "https://yourorg.atlassian.net/wiki"
  confluence_email     = var.confluence_email
  confluence_api_token = var.confluence_api_token

  azure_secret_id = module.azure_integration.secret_id

  azure_automation_account_name   = "saas-prod-automation"
  azure_automation_resource_group = "rg-saas-automation"

  alert_ingest_allowed_priorities = ["p2", "p3", "p4"]
  alert_ingest_blocked_services   = ["sandbox-test"]

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

## What It Creates

- 3 Agents: `saas-alert-ingest`, `saas-investigator`, `saas-remediator`
- 4 Runbook SOPs (alert normalization, auto-investigation, Confluence match, Azure Automation remediation)
- 1 Remediation pattern (`azure-automation-runbook`)
- 1 Workflow (`pagerduty-saas-incident-response`) with deterministic ingest filter and P1 remediation safety gate
- Optional `sg_webhook` for PagerDuty ingress when `enable_pagerduty_webhook = true`
- Internal integration submodules for Datadog, PagerDuty, Confluence, and Azure (or attach existing integrations)

## Workflow Stages

| Stage | Type | Purpose |
|-------|------|---------|
| alert-ingest-filter | policy_check (templated Rego) | Filter PagerDuty payloads by priority/service/environment |
| normalize-alert | agent | Parse and normalize alert JSON |
| auto-investigate | agent | Datadog + Azure root-cause analysis |
| match-confluence-runbook | agent | Find runbook and Automation metadata |
| remediation-safety-gate | policy_check (inline Rego) | Block P1/SEV1 auto-remediation |
| execute-azure-remediation | agent | Start Azure Automation runbook |

## Outputs

| Name | Description |
|------|-------------|
| `agent_names` | Map of alert-ingest / investigator / remediator agent names |
| `workflow_names` | Map including `pagerduty_saas_incident_response` |
| `*_integration_name` | Resolved Datadog, PagerDuty, Confluence, Azure integration names |
| `webhook_id` / `webhook_token` | PagerDuty ingress webhook credentials |
| `webhook_trigger_endpoint` / `webhook_ingress_payload_url` | StackGen trigger URLs when `webhook_trigger_base_url` is set |
