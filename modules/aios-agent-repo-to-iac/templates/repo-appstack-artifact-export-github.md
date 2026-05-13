Produce a deployable artifact and export to GitHub. Use **`stackgen-mcp-consumer-tool-catalog-sop`** for action runs, snapshots, and **`stackgen-mcp_get_current_violations`** when debugging policy.

## Steps

1. `stackgen-mcp_create_appstack_action_run` for plan/apply or platform-defined build that yields a deployable artifact; `stackgen-mcp_get_action_run` + `stackgen-mcp_get_action_run_logs` for evidence
2. Optional: `stackgen-mcp_get_current_violations` before promote
3. Optional: `stackgen-mcp_create_snapshot` after green state
4. **Export:** StackGen product **Export** toward **export_github_repo** (clone/push via GitHub integration + token on Ubuntu when automating); do not embed secrets — use Vault references in exported files. **Do not** assume `stackgen-mcp_download-iac`, `stackgen-mcp_push-appstack-to-git`, or related git MCP tools exist on the default user MCP.
