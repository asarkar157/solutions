# AIOS — Repository to IaC (StackGen MCP)

Registers one agent and **two workflows**: (1) **repository-to-iac** — analyze a repo and generate IaC via StackGen MCP; (2) **repo-scan-appstack-github-export** — scan a repo, infer modules/resource types, materialize an **appStack**, produce a **deployable artifact**, then **Export** (product) or Git push via **GitHub/Ubuntu** automation. Runbook **`stackgen-mcp-consumer-tool-catalog-sop`** documents the **StackGen user / AppStack** MCP tool matrix (`create_appstack`, `get_appstacks`, `create_appstack_action_run`, env profiles, snapshots, etc.).

## Prerequisites

- `aios-foundation` for `model_names`
- `aios-policies` for `policy_ids.dangerous_ops`
- `aios-integration-github` — pass `integration_name` into `github_integration_name`
- Optional: Guild integration for StackGen hosted MCP from Vault **Other/mcp** secrets — see `examples/agentic-infrastructure`

## Usage

```hcl
module "repo_to_iac" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-repo-to-iac?ref=main"

  # aios-foundation exposes model_names as list(string); pass it through.
  model_names = module.foundation.model_names

  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
  }

  github_integration_name = module.github_integration.integration_name

  stackgen_mcp_integration_name = "stackgen-mcp"
}
```

## Workflows

| Name | Required inputs | Purpose |
|------|-----------------|--------|
| `repository-to-iac` | `github_repo_url` | Fetch repo → analyze → StackGen IaC → summarize |
| `repo-scan-appstack-github-export` | `github_repo_url`, `export_github_repo` | Scan repo → plan appStack/modules → provision & wire → env (AWS/region) → deployable artifact → **Export** to target GitHub repo |

Optional inputs on the export workflow include `aws_region`, `stackgen_project_name`, `export_branch`, `default_branch`.

See [`personas/repo-to-iac-architect.md`](personas/repo-to-iac-architect.md) for agent behavior.
