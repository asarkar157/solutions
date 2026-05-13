# aios-agent-db-state-splitter

Guild agent plus **skills** (`sg_runbook_sop`) and **two workflows** for splitting a **monolithic Terraform/OpenTofu state** that may span **AWS, Azure, and GCP** into **logical resource groups** (tags, module paths, `grouping_policy_json`), optional **per-group TF roots / backends**, **multiple StackGen AppStacks** (via **StackGen MCP** when configured), **reverse-engineered IaC**, **registry + StackGen type mapping**, **orphan** handling through a **secondary** workflow, and **convergence loops** on resource counts and plans (including StackGen **Plan** action runs).

## Requirements

- **StackGen provider** `>= 0.1.12` (this module pins that minimum for `sg_agent.remote_runners` and `data.sg_remote_runner`).
- `module.foundation.model_names` and `module.policies.policy_ids.dangerous_ops` (typical stack).
- `modules/aios-integration-github` and `modules/aios-integration-ubuntu`.
- **Optional:** StackGen MCP Guild integration (same pattern as `aios-agent-repo-to-iac`) — pass `stackgen_mcp_integration_name` to enable AppStack tools (`create_appstack`, `add_resource_to_appstack`, `connect_resources`, `create_appstack_action_run`, env profiles, snapshots, etc.; see **`stackgen-mcp-consumer-tool-catalog-sop`**). Without it, the workflow still runs TF grouping/plans but **skips AppStack materialization** (documented in SOPs). When this is non-empty, **`db-state-split-architect`** adds **`hitl.always_allowed`** pattern **`<integration_name>_*`** (for example **`stackgen-mcp_*`** for prefix **`stackgen-mcp_`**) and attaches intervention policy **`db-state-split-stackgen-mcp-auto-approve`** (`policies/stackgen-mcp-auto-approve.rego`).

## Operator prerequisites (outside Terraform)

- **`monolith_state_uri` / `iac_repository_url`** are workflow inputs when you start **`db-monorepo-state-split-convergence`** in Guild — not variables on this module. The **Ubuntu CLI** (or **remote runner**) environment must be able to **fetch** state and **clone** the repo (tokens, cloud SDK auth, VPC egress to S3/GCS, etc.).
- **`remote_runner_name` + `remote_runner_attach_to_agent`** only select an existing Guild runner and attach it on `sg_agent`; they do **not** install tools or secrets on the runner image.

## Security & privacy

- Terraform state can contain **secrets**. SOPs instruct agents to **`note`** summaries and paths, not raw attribute maps. **`/tmp`** on shared runners may be visible across jobs — use tight directory permissions and cleanup when policy allows (see **db-state-split-orchestration-sop**).

## Continuous integration

- Repo **CI** runs **`scripts/terraform-validate-all.sh`** (includes this module) and **`scripts/verify-db-state-split-templates.sh`**, which renders **`db-state-split-orchestration.md.tftpl`** with dummy locals to catch **template syntax** errors early.

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

  # Optional: StackGen MCP integration name for AppStack (user MCP) tools.
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
Notable **optional inputs**: `grouping_policy_json`, `stackgen_project_name`, `cloud_discovery_id` (opaque correlation id for operators — **not** wired to MCP discovery import on the default user MCP).

## Reliability (what the prompts optimize for)

Guild traces on long runs showed **skill-search noise**, **`/workspace` read-only** sandboxes, **~300s Ubuntu timeouts** on monolithic shell commands, and **many redundant `get_appstacks` / `get_appstack_resources`** calls. The persona and runbooks in this module now steer the agent toward: **`/tmp` preflight**, **trusting prepended `[Runbook Context]` / `### Runbook:` text** (Guild injects runbook summaries per stage — avoid redundant **`search_skill`**), **`[Skills]` vs `load_skill`** (skip redundant loads when the runbook block already inlined the same name), **short `create_agent` goals** (scripts via `ubuntu-cli_create_files` instead of huge embedded `jq`), **`stackgen_appstack_list_cache`**, **one shard per plan step** (or remote-runner fan-out), **MCP list caching** during AppStack materialization, and **redacted `note` discipline** for state secrets. Remaining iteration limits, DAG deduplication, and cascade fallbacks are **Guild platform** concerns.

## Outputs

See `outputs.tf` — agent name, workflow names, `stackgen_mcp_auto_approve_policy_id`, optional webhook id/token.
