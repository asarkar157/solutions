Materialize canvas IaC and runtime context. Follow **`stackgen-mcp-consumer-tool-catalog-sop`** for tool names and UUID rules (StackGen **user** MCP).

## Steps

1. `stackgen-mcp_create_appstack` (`project_name`, `name`, `cloud_provider`; optional `appstack_ref_id` from templates)
2. **Brownfield:** map discovered repo / state artifacts → `stackgen-mcp_add_resource_to_appstack` / packs; the default user MCP does **not** expose `list_cloud_discoveries` / `create_appstack_from_discovered_resources`
3. `stackgen-mcp_add_resource_to_appstack` / `stackgen-mcp_add_resource_pack_to_appstack` as planned (**pack id = UUID only**)
4. `stackgen-mcp_get_possible_resource_connections` then `stackgen-mcp_connect_resources` for required wiring
5. `stackgen-mcp_get_env_profiles`; `stackgen-mcp_create_env_profile` or `stackgen-mcp_update_env_profile` — populate environment variables and binds using workflow `aws_region` and AWS integration metadata (region/account context); align names with app repo conventions
6. `stackgen-mcp_get_current_violations` before treating the stack as ready
7. Drive readiness with **`stackgen-mcp_create_appstack_action_run`** (Plan, then Apply only when policy allows) — there is no `provision_appstack` tool on the user MCP
