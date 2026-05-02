# AIOS Agent — Supply Chain Security

npm supply chain attack detection: SLSA provenance checks, behavioral sandbox, phantom dependency detection.

## Usage

```hcl
module "supply_chain" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-supply-chain-security"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  # Prefer the integration name from your GitHub integration module:
  github_integration_name = module.github_integration.integration_name

  # Legacy: if github_integration_name is empty, a non-empty github_token still attaches "github-integration".
}
```
