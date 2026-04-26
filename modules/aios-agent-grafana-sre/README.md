# AIOS Agent — Grafana Observability SRE

Self-contained Grafana SRE agent with 8 runbooks following Google SRE and DORA practices. Creates its own integration.

## Usage

```hcl
module "grafana_sre" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-grafana-sre"

  model_names       = module.foundation.model_names
  policy_ids        = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  grafana_base_url  = "https://grafana.example.com"
  grafana_api_token = var.grafana_token
}
```
