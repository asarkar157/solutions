# AIOS Agent — PrivateSaaS DevOps/SRE

DevOps/SRE for PrivateSaaS (private VPC, no public SaaS assumptions): Grafana alert ingestion, deterministic ingest filtering, Grafana + AWS + Palo Alto PAN-OS investigation, bounded AWS remediation, and read-only connectivity audit.

## Usage

```hcl
module "privatesaas_devops_sre" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-privatesaas-devops-sre?ref=main"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    sre_remediation = module.policies.policy_ids.sre_remediation
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  private_saas_environment_label = "prod-vpc-us-east-1"

  grafana_server = "https://grafana.internal.example.com"
  grafana_token  = var.grafana_token

  aws_secret_id = module.aws_integration.secret_id

  paloalto_management_url = "https://fw-mgmt.internal.example.com"
  paloalto_api_key        = var.paloalto_api_key
  paloalto_vsys           = "vsys1"
  paloalto_device_group_hints = ["prod-dg"]

  alert_ingest_allowed_environments = ["production", "staging"]
  alert_ingest_blocked_alert_names  = ["TestAlert"]

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id
}
```

## What It Creates

- 3 Agents: `grafana-alert-ingest`, `privatesaas-investigator`, `privatesaas-remediator`
- 9 Runbook SOPs (alert normalization, Grafana/AWS/firewall investigation, remediation recommendations, connectivity audit)
- 2 Workflows: `privatesaas-incident-response`, `privatesaas-connectivity-audit`
- Optional `sg_webhook` for Grafana ingress when `enable_grafana_webhook = true`
- Internal integration submodules for Grafana, AWS, and Palo Alto (or attach existing integrations)

## Workflow Stages — Incident Response

| Stage | Type | Purpose |
|-------|------|---------|
| grafana-ingest-filter | policy_check (templated Rego) | Filter Grafana payloads by severity/environment/namespace |
| normalize-alert | agent | Parse and normalize alert JSON |
| collect-grafana-signals | agent | Grafana dashboard and Prometheus signals |
| correlate-aws-changes | agent | ECS/EKS/EC2 and CloudTrail correlation |
| analyze-firewall-path | agent | PAN-OS traffic/threat logs (read-only) |
| synthesize-incident-report | agent | DevOps/SRE summary with network + infra correlation |
| remediation-safety-gate | policy_check (inline Rego) | Block P1/SEV1 auto-remediation |
| recommend-remediation | agent | Safe AWS actions; firewall recommendations only (no rule pushes) |

## Workflow Stages — Connectivity Audit

| Stage | Type | Purpose |
|-------|------|---------|
| grafana-health-snapshot | agent | Grafana datasource and alertmanager health |
| aws-network-snapshot | agent | VPC/subnet/route/security group topology |
| firewall-policy-review | agent | PAN-OS policy inventory and hit counts (read-only) |

## Outputs

| Name | Description |
|------|-------------|
| `agent_names` | Map of alert-ingest / investigator / remediator agent names |
| `workflow_names` | Map including `privatesaas_incident_response` and `privatesaas_connectivity_audit` |
| `grafana_integration_name` / `aws_integration_name` / `paloalto_integration_name` | Resolved integration names |
| `webhook_id` / `webhook_token` | Grafana ingress webhook credentials |
| `webhook_trigger_endpoint` / `webhook_ingress_payload_url` | StackGen trigger URLs when `webhook_trigger_base_url` is set |

## Firewall guardrails

The remediator persona and workflow explicitly prohibit PAN-OS rule pushes. Firewall findings are emitted as recommendations and change-ticket text for human operators.
