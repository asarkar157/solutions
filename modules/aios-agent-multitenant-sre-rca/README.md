# AIOS Agent — Multi-Tenant SRE RCA

Aiden for SRE on multi-tenant SaaS: Datadog alert ingestion, cross-signal RCA (Datadog, GCP Cloud Logging, AWS ECS/CloudTrail, GitHub), Slack publish, and thread-based collaboration for follow-up questions.

## Usage

```hcl
module "multitenant_sre_rca" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-multitenant-sre-rca?ref=main"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
    data_risk_pii = module.policies.policy_ids.data_risk_pii
  }
  policy_create_flags = {
    data_risk_pii = true
  }

  datadog_api_key = var.datadog_api_key
  datadog_app_key = var.datadog_app_key

  gcp_secret_id   = module.gcp_integration.secret_id
  gcp_project_id  = var.gcp_project_id

  aws_secret_id   = module.aws_integration.secret_id
  github_token    = var.github_token
  slack_bot_token = var.slack_bot_token

  slack_rca_channel                  = "#sre-rca"
  slack_collaboration_channel_hint   = "#sre-rca"
  alert_ingest_allowed_tenant_ids    = ["acme-prod", "beta-tenant"]
  alert_ingest_blocked_services      = ["sandbox-test"]

  github_default_org   = "yourorg"
  github_default_repos = ["yourorg/platform-api", "yourorg/checkout-service"]
  aws_ecs_cluster_hints = {
    checkout = "prod-ecs-cluster"
  }

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

## What It Creates

- 4 Agents: `datadog-alert-ingest`, `rca-investigator`, `rca-publisher`, `rca-collaborator`
- 5 Runbook SOPs (alert normalization, cross-signal investigation, RCA synthesis, Slack publish, collaboration)
- 2 Workflows (`datadog-multitenant-rca`, `datadog-rca-collaboration`)
- Optional `sg_evidence_checklist` (`multitenant-rca`)
- Optional `sg_webhook` resources for Datadog alert ingress and Slack thread collaboration
- Internal integration submodules for Datadog, GCP, AWS, GitHub, and Slack (or attach existing integrations)

## Workflow A — datadog-multitenant-rca

| Stage | Type | Purpose |
|-------|------|---------|
| alert-ingest-filter | policy_check (templated Rego) | Filter by priority, tenant_id allowlist, blocked services/tags |
| normalize-alert | agent | Parse Datadog alert and extract tenant scope |
| cross-signal-investigate | agent | Datadog + GCP + AWS + GitHub read-only analysis |
| synthesize-rca | agent | Structured RCA JSON synthesis |
| publish-rca-slack | agent | Post RCA to Slack with investigation_id |

## Workflow B — datadog-rca-collaboration

| Stage | Type | Purpose |
|-------|------|---------|
| collaborate | agent | Thread follow-up on completed investigations |

## Outputs

| Name | Description |
|------|-------------|
| `agent_names` | Map of alert-ingest / investigator / publisher / collaborator agent names |
| `workflow_names` | Map including `datadog_multitenant_rca` and `datadog_rca_collaboration` |
| `*_integration_name` | Resolved Datadog, GCP, AWS, GitHub, Slack integration names |
| `evidence_checklist_name` | Evidence checklist when enabled |
| `webhook_id` / `webhook_token` | Datadog ingress webhook credentials |
| `collaboration_webhook_id` / `collaboration_webhook_token` | Slack collaboration webhook credentials |
| `webhook_trigger_endpoint` / `webhook_ingress_payload_url` | StackGen trigger URLs when `webhook_trigger_base_url` is set |
