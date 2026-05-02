StackGen Consumer MCP tool chain for declarative IaC on the canvas (use exact tool names from the integration).

## Steps

1. **Context:** `stackgen-mcp_me` — caller/project scope
2. **Discovery:** `stackgen-mcp_get_appstacks`; `stackgen-mcp_get_supported_resource_types` (templates under labels `["template"]`, resource packs listed here); `stackgen-mcp_get_appstack_resources`; `stackgen-mcp_get_resource_configurations` and `stackgen-mcp_get_resource_type_configurations`
3. **Greenfield:** `stackgen-mcp_create_appstack` (optional `appstack_ref_id` from templates); `stackgen-mcp_add_resource_to_appstack`; `stackgen-mcp_add_resource_pack_to_appstack` (UUID from `get_supported_resource_types`); `stackgen-mcp_connect_resources` after `stackgen-mcp_get_possible_resource_connections`
4. **Brownfield:** `stackgen-mcp_update_resource`; `stackgen-mcp_delete_resource`; snapshot `stackgen-mcp_create_snapshot` before risky edits; `stackgen-mcp_restore_snapshot` to roll back canvas state
5. **Governance:** `stackgen-mcp_get_current_violations` before merge/promote
6. **Terraform stubs in appstack:** `stackgen-mcp_get_*` and `create/update/delete_*` for `appstack_tf_variables`, `appstack_tf_locals`, `appstack_tf_outputs`, `appstack_tf_providers` as needed
7. **Runs:** `stackgen-mcp_create_appstack_action_run`; `stackgen-mcp_get_action_run`; `stackgen-mcp_get_action_run_logs`
8. **Env profiles:** `stackgen-mcp_get_env_profiles`; `stackgen-mcp_create_env_profile`; `stackgen-mcp_update_env_profile`; `stackgen-mcp_delete_env_profile`
9. **Snapshots list:** `stackgen-mcp_get_snapshots`
10. **AWS live state:** use `aws_production` integration `run_shell` + AWS CLI for accounts/resources outside the StackGen graph when required
