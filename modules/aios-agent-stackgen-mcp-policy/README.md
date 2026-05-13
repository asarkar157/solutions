# StackGen MCP Integration & Policy Module

This module demonstrates how to configure an AI Agent that connects to StackGen over the Model Context Protocol (MCP). The Vault **`Other` / `mcp`** secret uses **`transport`**, **`url`**, and **`headers`** (Bearer token) — the same wiring as [`examples/agentic-infrastructure`](../../examples/agentic-infrastructure/main.tf) and [`examples/repo-to-iac`](../../examples/repo-to-iac/main.tf). If `stackgen_mcp_url` contains `/mcp/sse`, **`transport` is `sse`**; otherwise it defaults to **`streamable_http`** (e.g. Consumer-style `/api/mcp/user` URLs).

More importantly, it serves as a reference architecture for **Authoring and Enforcing Guardrails (Policies)** on Agent actions.

## Key Features

1. **MCP integration**: Provisions `sg_guild_integration` with `type = "mcp"` and a Vault MCP secret whose metadata matches the repo’s standard **`transport` / `url` / `headers`** pattern.
2. **Rego Policy Guardrails**: `policies/stackgen-guardrails.rego` allow-lists **read-style** MCP tool suffixes that exist on the StackGen **user / AppStack** MCP (`get_appstacks`, `get_appstack_resources`, env profiles, action-run logs, TF block reads, violations, snapshots, etc.) so the audit agent cannot call mutating tools.
3. **Policy Attachment**: Uses `sg_agent_policy_attachment` to bind the Rego guardrail safely to the `stackgen-expert` agent.

## Example Usage

```hcl
module "stackgen_mcp_agent" {
  source = "./modules/aios-agent-stackgen-mcp-policy"

  stackgen_mcp_url   = "https://app.stackgen.com/api/mcp/sse"
  stackgen_api_token = var.my_secure_token
  model_names        = ["gpt-4o"]
}
```
