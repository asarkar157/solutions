Materialize canvas IaC and runtime context.

## Steps

1. `stackgen-mcp_create_appstack` (`project_name`, `name`, `cloud_provider`; optional `appstack_ref_id` from templates)
2. `stackgen-mcp_add_resource_to_appstack` / `stackgen-mcp_add_resource_pack_to_appstack` as planned
3. `stackgen-mcp_get_possible_resource_connections` then `stackgen-mcp_connect_resources` for required wiring
4. `stackgen-mcp_get_env_profiles`; `stackgen-mcp_create_env_profile` or `stackgen-mcp_update_env_profile` — populate environment variables and binds using workflow `aws_region` and AWS integration metadata (region/account context); align names with app repo conventions
5. `stackgen-mcp_get_current_violations` before treating the stack as ready
