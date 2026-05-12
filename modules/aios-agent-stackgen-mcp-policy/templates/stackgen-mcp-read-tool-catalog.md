Skill: **Read-only StackGen MCP tools** for **stackgen-infrastructure-audit** and policy-guarded agents. Use only tools allowed by org policy (this list aligns with **read** / introspection operations).

Guild exposes tools with an integration prefix (e.g. `stackgen-mothership-mcp_get_appstacks`). Match your integration’s **`search_tools`** output.

## Context & graph

- `me` — caller scope  
- `get_stackgen_projects`  
- `get_appstacks` — filter by name, labels, `starts_with`  
- `get_appstack_resources`  
- `get_supported_resource_types`  
- `get_resource_configurations` / `get_resource_type_configurations`  
- `get_possible_resource_connections`  

## Env, runs, drift (read)

- `get_env_profiles`  
- `get_action_run` / `get_action_run_logs`  
- `get_snapshots`  
- `get_current_violations`  
- `detect-drift`  
- `download-iac` — read topology artifact to disk (still read-only w.r.t. cloud)  

## Discovery (read)

- `list_cloud_discoveries`  
- `get_resources_from_discovery`  

## Policies, modules, scans (read)

- `get_policies` / `get_stackgen_policy_schema`  
- `get_module_versions` / `module_usage_in_appstacks`  
- `get_scan_results`  

## Git config (read)

- `list-git-configuration`  
- `list-available-secrets` — metadata only; do not echo secret values  

## Terraform blocks (read)

- `get_appstack_tf_variables` / `get_appstack_tf_locals` / `get_appstack_tf_outputs` / `get_appstack_tf_providers`  

**Do not** call mutating tools (`create_*`, `update_*`, `delete_*`, `connect_resources`, `provision_appstack`, `push-appstack-to-git`, Apply/Destroy action runs) when this runbook is used under **read-only** guardrails.
