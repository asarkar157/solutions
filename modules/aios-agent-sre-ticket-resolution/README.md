# AIOS Agent — SRE Ticket Resolution

SRE workflow for ServiceNow ticket resolution: webhook ingest with deterministic filtering, ticket enrichment, Grafana (Prometheus) + AWS investigation, bounded AWS remediation with P1/Critical safety gate, and Slack notification.

## Usage

```hcl
module "sre_ticket_resolution" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-sre-ticket-resolution?ref=main"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    sre_remediation = module.policies.policy_ids.sre_remediation
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  servicenow_instance_url = "https://your-org.service-now.com"
  servicenow_username     = var.servicenow_username
  servicenow_password     = var.servicenow_password

  grafana_server = "https://grafana.example.com"
  grafana_token  = var.grafana_token

  aws_secret_id = module.aws_integration.secret_id

  slack_bot_token      = var.slack_bot_token
  slack_signing_secret = var.slack_signing_secret
  slack_channel_hint   = "#sre-incidents"

  ticket_ingest_allowed_priorities = ["p2", "p3", "p4", "3 - moderate"]
  ticket_ingest_blocked_short_description_substrings = ["test ticket", "sandbox"]

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

## What It Creates

- 3 Agents: `ticket-intake`, `ticket-investigator`, `ticket-resolver`
- 4 Runbook SOPs (enrichment, investigation, propose resolution, resolve and notify)
- 1 Workflow (`servicenow-ticket-resolution`) with deterministic ingest filter and P1/Critical remediation safety gate
- Optional `sg_webhook` `servicenow-ticket-receiver` when `enable_servicenow_webhook = true`
- Internal integration submodules for ServiceNow, AWS, Grafana, and Slack (or attach existing integrations)

## Workflow Stages

| Stage | Type | Purpose |
|-------|------|---------|
| ticket-ingest-filter | policy_check (templated Rego) | Filter ServiceNow payloads by priority, assignment group, category |
| enrich-ticket | agent | Parse ticket, work notes, Slack notify |
| investigate | agent | Grafana/Prometheus + AWS root-cause analysis |
| propose-resolution | agent | Plan bounded AWS remediation |
| resolution-safety-gate | policy_check (inline Rego) | Block P1/Critical auto-remediation |
| resolve-and-notify | agent | Execute safe AWS actions, update ServiceNow, Slack summary |

## Outputs

| Name | Description |
|------|-------------|
| `agent_names` | Map of intake / investigator / resolver agent names |
| `workflow_names` | Map including `servicenow_ticket_resolution` |
| `*_integration_name` | Resolved ServiceNow, AWS, Grafana, Slack integration names |
| `webhook_id` / `webhook_token` | ServiceNow ingress webhook credentials |
| `webhook_trigger_endpoint` / `webhook_ingress_payload_url` | StackGen trigger URLs when `webhook_trigger_base_url` is set |
