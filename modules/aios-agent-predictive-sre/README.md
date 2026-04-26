# AIOS Agent — Predictive SRE

Cross-domain predictive triage agent that correlates GitHub, Grafana, and AWS signals to predict failures.

## Usage

```hcl
module "predictive_sre" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-predictive-sre"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  agent_names = {
    github_agent  = module.software_engineering.agent_names.cursor_developer
    grafana_agent = module.grafana_sre.agent_name
    aws_agent     = module.aws_sre.aws_sre_agent_name
  }

  integration_names = {
    github  = module.github_integration.integration_name
    grafana = module.grafana_sre.integration_name
    aws     = module.aws_integration.integration_name
  }
}
```
