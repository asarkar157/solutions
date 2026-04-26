# AIOS Agent — Supply Chain Security

npm supply chain attack detection: SLSA provenance checks, behavioral sandbox, phantom dependency detection.

## Usage

```hcl
module "supply_chain" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-supply-chain-security"

  model_names  = module.foundation.model_names
  policy_ids   = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  github_token = var.github_token
}
```
