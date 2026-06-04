# AIOS Agent — Grafana Alert Triage

Tiered Grafana alert-storm triage: webhook ingress, Rego ingest filter, prior-incident memory search, PromQL query probe, ReAcTree hypothesis RCA, optional cloud escalation, and Slack publish.

## Usage

```hcl
module "alert_triage" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-alert-triage?ref=main"

  model_names = module.foundation.model_names
  policy_ids  = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
  }

  existing_grafana_integration_name = module.grafana_integration.integration_name
  existing_slack_integration_name   = module.slack_integration.integration_name

  # Optional cross-signal wiring
  # aws_secret_id   = module.aws_integration.secret_id
  # github_token    = var.github_token
  # remote_runner_name = "alert-triage-k8s-runner"
}
```

## Workflow stages

1. `grafana-ingest-filter` — Rego policy gate
2. `normalize-alert` — stable `normalized_alert` JSON
3. `search-prior-incidents` — `memory_search` on `shared:incidents`
4. `classify-symptom-cause` — symptom vs cause tagging
5. `collect-grafana-signals` — golden signals + related alerts
6. `probe-grafana-queries` — `get_alert_rule` + `query_metric` + datasource probe
7. `enrich-k8s-context` — remote runner kubectl (optional)
8. `cross-signal-investigate` — ReAcTree hypothesis subagents
9. `synthesize-rca` — structured RCA JSON
10. `persist-incident-memory` — write-back to shared memory
11. `cloud-triage` — dynamic cloud agent escalation when needed
12. `notify-slack` — RCA narrative post

## Outputs

| Name | Description |
|------|-------------|
| `workflow_name` | Primary workflow name |
| `agent_names` | Coordinator, ingest, investigator |
| `webhook_token` | Grafana contact point token |
| `webhook_ingress_payload_url` | Full trigger URL when `webhook_trigger_base_url` set |
