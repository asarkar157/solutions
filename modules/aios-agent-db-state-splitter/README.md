# aios-agent-db-state-splitter

Guild agent plus **skills** (`sg_runbook_sop`) and **two workflows** for splitting a **monolithic Terraform/OpenTofu state** that may span **AWS, Azure, and GCP** into **logical resource groups** (tags, module paths, `grouping_policy_json`), optional **per-group TF roots / backends**, **multiple StackGen AppStacks** (via **StackGen MCP** when configured), **reverse-engineered IaC**, **registry + StackGen type mapping**, **orphan** handling through a **secondary** workflow, and **convergence loops** on resource counts and plans (including StackGen **Plan** action runs).

## Requirements

- **StackGen provider** `>= 0.1.12` (this module pins that minimum for `sg_agent.remote_runners` and `data.sg_remote_runner`).
- `module.foundation.model_names` and `module.policies.policy_ids.dangerous_ops` (typical stack).
- `modules/aios-integration-github` and `modules/aios-integration-ubuntu`.
- **Optional:** StackGen MCP Guild integration (same pattern as `aios-agent-repo-to-iac`) — pass `stackgen_mcp_integration_name` to enable `create_appstack`, `add_resource_to_appstack`, `create_appstack_from_discovered_resources`, `download-iac`, etc. Without it, the workflow still runs TF grouping/plans but **skips AppStack materialization** (documented in SOPs). When this is non-empty, **`db-state-split-architect`** adds **`hitl.always_allowed`** pattern **`<integration_name>_*`** (for example **`stackgen-mcp_*`** for prefix **`stackgen-mcp_`**) and attaches intervention policy **`db-state-split-stackgen-mcp-auto-approve`** (`policies/stackgen-mcp-auto-approve.rego`).

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

  # Optional: Guild remote runner — documents in SOPs; set attach to bind on the agent (runner must exist at plan).
  # remote_runner_name             = "org-tofu-runner"
  # remote_runner_attach_to_agent  = true

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

## Reliability (what the prompts optimize for)

Guild traces on long runs showed **skill-search noise**, **`/workspace` read-only** sandboxes, **~300s Ubuntu timeouts** on monolithic shell commands, and **many redundant `get_appstacks` / `get_appstack_resources`** calls. The persona and runbooks in this module now steer the agent toward: **`/tmp` preflight**, **trusting prepended `[Runbook Context]` / `### Runbook:` text** (Guild injects runbook summaries per stage — avoid redundant **`search_skill`**), **short `create_agent` goals** (scripts via `ubuntu-cli_create_files` instead of huge embedded `jq`), **`stackgen_appstack_list_cache`**, **one shard per plan step** (or remote-runner fan-out), and **MCP list caching** during AppStack materialization.

## Outputs

See `outputs.tf` — agent name, workflow names, `stackgen_mcp_auto_approve_policy_id`, optional webhook id/token.
