# aios-agent-privatesaas-sre

**Aiden for SRE** on PrivateSaaS: FireHydrant + private Grafana ingest, GCP investigation, internal operator tooling, multi-source runbook matching, RCA synthesis, and document-only production remediation recommendations.

| Agents | Workflows | Integrations |
|--------|-----------|--------------|
| `incident-ingest`, `privatesaas-sre-investigator`, `runbook-coordinator` | `privatesaas-incident-response`, `privatesaas-runbook-audit` | Grafana, GCP, FireHydrant, internal `restapi` |

No AWS integration is required.

## LLM — Bifrost (customer gateway)

Register Bifrost in the consumer root as an **OpenAI-compatible** `sg_guild_model_provider` pointing at the customer gateway, then wire model names into this module.

```hcl
# Consumer root — alongside module.foundation
resource "sg_secret" "bifrost" {
  name        = "bifrost-vault"
  description = "Bifrost gateway API key"
  category    = "LLM"
  subcategory = "openai"
  metadata = {
    OPENAI_API_KEY = var.bifrost_api_key
  }
}

resource "sg_guild_model_provider" "bifrost" {
  name            = "bifrost"
  provider_type   = "openai"
  host            = var.bifrost_gateway_url # e.g. https://bifrost.internal.example.com/v1
  token_reference = sg_secret.bifrost.name
}

resource "sg_guild_model" "bifrost_primary" {
  name          = "bifrost-gpt-5.4"
  provider_name = sg_guild_model_provider.bifrost.name
  model_id      = "gpt-5.4-2026-03-05" # route id exposed by Bifrost
  good_for_task = "tool_calling"
}

module "privatesaas_sre" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-privatesaas-sre?ref=main"

  model_names = [sg_guild_model.bifrost_primary.name]
  # Or: model_names = [module.foundation.model_names_by_provider.bifrost]
  # Optional explicit override:
  # bifrost_model_names   = [sg_guild_model.bifrost_primary.name]
  bifrost_gateway_url = var.bifrost_gateway_url # documentation / workflow description only

  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    sre_remediation = module.policies.policy_ids.sre_remediation
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  grafana_server       = "https://grafana.internal.example.com"
  grafana_token        = var.grafana_token
  gcp_credentials_json = var.gcp_credentials_json
  gcp_project_id       = var.gcp_project_id
  firehydrant_api_key  = var.firehydrant_api_key
  internal_tool_base_url = "https://console.internal.example.com/api/v1"
  internal_tool_api_key  = var.internal_console_token

  external_runbook_catalog = {
    "checkout-latency" = {
      url         = "https://wiki.internal.example.com/sre/checkout-latency"
      description = "Checkout API latency runbook"
    }
  }

  enable_grafana_webhook     = true
  enable_firehydrant_webhook = true
  webhook_trigger_base_url   = var.stackgen_url
}
```

When `bifrost_model_names` is non-empty, it replaces `model_names` on all agents (useful when foundation also registers public-cloud models you do not want on PrivateSaaS agents).

## Workflows

### `privatesaas-incident-response`

1. `incident-ingest-filter` (Rego: severity, service, environment)
2. `normalize-incident` — FireHydrant + Grafana
3. `collect-grafana-signals`
4. `investigate-gcp`
5. `enrich-firehydrant`
6. `query-internal-tooling`
7. `match-runbooks` — runbook-coordinator
8. `synthesize-rca`
9. `remediation-safety-gate` (P1 block)
10. `recommend-actions` (document-only for prod)

### `privatesaas-runbook-audit` (read-only)

1. `inventory-runbooks`
2. `coverage-gaps`

## Module runbooks

Three generic SOPs ship with the module; stage-specific SOPs cover each workflow step. Pass additional URLs via `external_runbook_catalog`.

## Policy keys

| Key | Required |
|-----|----------|
| `dangerous_ops` | yes |
| `sre_remediation` | optional (default attachments on investigator) |
| `prod_write_gate` | optional |

## Outputs

See `outputs.tf` for agent/workflow/integration names and optional webhook ingress URLs.
