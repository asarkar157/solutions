# AIOS Agent — Workspace Assistant

Google Workspace + Slack + Linear triage agent for daily developer workflows and ticket management.

## Usage

```hcl
module "workspace" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-workspace-assistant"

  model_names = module.foundation.model_names
  policy_ids  = {
    dangerous_ops          = module.policies.policy_ids.dangerous_ops
    google_tool_governance = module.policies.policy_ids.google_tool_governance
  }

  integration_names = {
    google = "google-workspace"
    slack  = module.slack_integration.integration_name
    linear = "linear-integration"
  }
}
```
