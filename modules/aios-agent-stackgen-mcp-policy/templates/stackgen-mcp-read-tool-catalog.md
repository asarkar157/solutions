Skill: **Read-only StackGen MCP tools** for **stackgen-infrastructure-audit** and policy-guarded agents. Aligns with the **StackGen user / AppStack** MCP (`…/api/mcp/user` style URLs): only **read / introspection** tools that exist on that server. Use **`search_tools`** if your org mounts a broader MCP — this list is the **minimum** accurate set.

Guild exposes tools with an integration prefix (e.g. `stackgen-mcp_get_appstacks`).

## Identity & inventory

- `me` — caller scope
- `get_appstacks` — filter by name, labels, `starts_with`
- `get_appstack_resources`
- `get_supported_resource_types`
- `get_resource_configurations` / `get_resource_type_configurations`
- `get_possible_resource_connections`

## Env, runs, snapshots, policy (read)

- `get_env_profiles`
- `get_action_run` / `get_action_run_logs`
- `get_snapshots`
- `get_current_violations`

## Terraform blocks (read)

- `get_appstack_tf_variables` / `get_appstack_tf_locals` / `get_appstack_tf_outputs` / `get_appstack_tf_providers`

**Not on user MCP (omit from read catalog for that integration):** `get_stackgen_projects`, `list_cloud_discoveries`, `get_resources_from_discovery`, `get_module_versions`, `module_usage_in_appstacks`, `get_policies`, `get_scan_results`, `download-iac`, `detect-drift`, `list-git-configuration`, `list-available-secrets`, graph helpers like `get_application_graph` unless your integration actually lists them.

**Do not** call mutating tools (`create_*`, `update_*`, `delete_*`, `connect_resources`, Apply/Destroy action runs) when this runbook is used under **read-only** guardrails.
