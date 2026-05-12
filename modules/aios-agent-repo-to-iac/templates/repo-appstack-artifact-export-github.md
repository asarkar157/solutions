Produce a deployable artifact and export to GitHub. Use **`stackgen-mcp-consumer-tool-catalog-sop`** for action runs, snapshots, drift, download, and git push tools.

## Steps

1. `stackgen-mcp_create_appstack_action_run` for plan/apply or platform-defined build that yields a deployable artifact; `stackgen-mcp_get_action_run` + `stackgen-mcp_get_action_run_logs` for evidence
2. Optional: `stackgen-mcp_detect-drift` (exact tool name from integration) before promote
3. Optional: `stackgen-mcp_download-iac` to a known path for tarball/text evidence
4. Optional: `stackgen-mcp_create_snapshot` after green state
5. **Export:** StackGen product **Export** **or** `stackgen-mcp_add-git-configuration` + `stackgen-mcp_push-appstack-to-git` (after `stackgen-mcp_list-available-secrets` / `stackgen-mcp_list-git-configuration`) to emit Terraform/OpenTofu into **export_github_repo**; do not embed secrets — use Vault references in exported files.
