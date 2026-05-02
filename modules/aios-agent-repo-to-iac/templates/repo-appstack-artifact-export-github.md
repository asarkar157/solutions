Produce a deployable artifact and export to GitHub.

## Steps

1. `stackgen-mcp_create_appstack_action_run` for plan/apply or platform-defined build that yields a deployable artifact; `stackgen-mcp_get_action_run` + `stackgen-mcp_get_action_run_logs` for evidence
2. Optional: `stackgen-mcp_create_snapshot` after green state
3. **Export:** use StackGen product **Export** (UI or product-documented flow) to emit Terraform/OpenTofu into the **export_github_repo** requested on the workflow; if an MCP export tool appears in stackgen-mcp discovery, prefer it and pass owner/repo from workflow inputs. Open PR or push per org policy; do not embed secrets — use Vault references in exported files.
