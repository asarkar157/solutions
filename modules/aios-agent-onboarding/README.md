# AIOS Agent — Developer Onboarding

Automated developer onboarding agent for environment setup, access provisioning, and codebase orientation.

## Usage

```hcl
module "onboarding" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-onboarding"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    slack  = module.slack_integration.integration_name
    github = module.github_integration.integration_name
    linear = "linear-integration"
  }
}
```
