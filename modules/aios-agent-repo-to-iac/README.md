# AIOS — Repository to IaC (StackGen MCP)

Registers one agent and **two workflows**: (1) **repository-to-iac** — analyze a repo and generate IaC via StackGen MCP; (2) **repo-scan-appstack-github-export** — scan a repo, infer modules/resource types, materialize an **appStack** (resources, connections, env profiles with AWS region/context), produce a **deployable artifact**, then **Export** generated IaC to a **target GitHub repo** using StackGen’s Export flow (see runbooks for MCP tool names).

## Prerequisites

- `aios-foundation` for `model_names`
- `aios-policies` for `policy_ids.dangerous_ops`
- `aios-integration-github` — pass `integration_name` into `github_integration_name`
- Optional: Guild integration for StackGen hosted MCP from Vault **Other/mcp** secrets — see `examples/agentic-infrastructure`

## Usage

```hcl
module "repo_to_iac" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-repo-to-iac?ref=main"

  model_names = {
    gpt4o         = module.foundation.model_names.gpt4o
    claude_sonnet = module.foundation.model_names.claude_sonnet
  }

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
