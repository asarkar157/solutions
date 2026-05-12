# aios-agent-db-state-splitter

Guild agent plus **skills** (`sg_runbook_sop`) and **two workflows** for splitting a **monolithic Terraform/OpenTofu state** that may span **AWS, Azure, and GCP** into **logical resource groups** (tags, module paths, `grouping_policy_json`), optional **per-group TF roots / backends**, **multiple StackGen AppStacks** (via **StackGen MCP** when configured), **reverse-engineered IaC**, **registry + StackGen type mapping**, **orphan** handling through a **secondary** workflow, and **convergence loops** on resource counts and plans (including StackGen **Plan** action runs).

## Requirements

- `module.foundation.model_names` and `module.policies.policy_ids.dangerous_ops` (typical stack).
- `modules/aios-integration-github` and `modules/aios-integration-ubuntu`.
- **Optional:** StackGen MCP Guild integration (same pattern as `aios-agent-repo-to-iac`) — pass `stackgen_mcp_integration_name` to enable `create_appstack`, `add_resource_to_appstack`, `create_appstack_from_discovered_resources`, `download-iac`, etc. Without it, the workflow still runs TF grouping/plans but **skips AppStack materialization** (documented in SOPs).

## Usage

```hcl
module "db_state_splitter" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-db-state-splitter?ref=main"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    github     = module.github_integration.integration_name
    ubuntu_cli = module.ubuntu_integration.integration_name
  }

  # Optional: StackGen MCP integration name for AppStack / discovery tools.
  # stackgen_mcp_integration_name = module.your_stackgen_mcp.integration_name

  # Optional: operator-configured Guild remote runner for heavy plan fan-out (see variables.tf).
  # remote_runner_name = "org-tofu-runner"

  # Optional: GitHub ingress to primary workflow (default false to avoid duplicate webhooks).
  # enable_github_webhook = true
}
```

## Workflows

| Name | Purpose |
|------|---------|
| `db-monorepo-state-split-convergence` | Multi-cloud logical grouping, count gate, reverse IaC, **StackGen AppStack materialization**, orphan handoff, TF + StackGen plan convergence |
| `orphan-iac-module-authoring` | Scaffold modules from `orphans_bundle`, validate, persist `orphan_modularization_memory` |

Primary workflow **required inputs**: `monolith_state_uri`, `iac_repository_url`.  
Notable **optional inputs**: `grouping_policy_json`, `stackgen_project_name`, `cloud_discovery_id` (for `create_appstack_from_discovered_resources` flows).

## Outputs

See `outputs.tf` — agent name, workflow names, optional webhook id/token.
