# AIOS Agent — Software Engineering

Linear + Cursor + GitHub development pipeline: analyze tickets, author code, submit PRs.

## Usage

```hcl
module "software_engineering" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-software-engineering"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    linear_mcp = "linear-integration"
    cursor_mcp = "cursor-tool"
    github     = module.github_integration.integration_name
    slack      = module.slack_integration.integration_name
  }
}
```
