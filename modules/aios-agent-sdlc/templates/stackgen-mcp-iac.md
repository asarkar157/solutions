Skill: **StackGen Consumer MCP** for SDLC **cloud_infra** and developer-intake flows (`stackgen-mcp_*` tool prefix on your integration).

Full cross-repo catalog: **`stackgen-mcp-consumer-tool-catalog-sop`** in `aios-agent-repo-to-iac` (same MCP server). This runbook is the **condensed operator chain** for greenfield + brownfield requests.

## 1. Context & inventory

- `stackgen-mcp_me` — org / caller scope  
- `stackgen-mcp_get_stackgen_projects` — project UUIDs  
- `stackgen-mcp_get_appstacks` — list stacks; `labels: ["template"]` for templates  
- `stackgen-mcp_get_appstack_resources` — what is on a stack  
- `stackgen-mcp_get_supported_resource_types` — **resource pack UUIDs** + allowed `resource_type` strings  

## 2. Greenfield canvas

- `stackgen-mcp_create_appstack` — optional `appstack_ref_id` from template  
- `stackgen-mcp_add_resource_to_appstack` — valid **`identifier`** (lowercase snake); correct **`resource_type`**  
- `stackgen-mcp_add_resource_pack_to_appstack` — **UUID only** for pack id  
- `stackgen-mcp_get_possible_resource_connections` → `stackgen-mcp_connect_resources`  

## 3. Brownfield / discovery

- `stackgen-mcp_list_cloud_discoveries` / `stackgen-mcp_get_resources_from_discovery`  
- `stackgen-mcp_create_appstack_from_discovered_resources` — `discovery_id` + `resources[]`  
- `stackgen-mcp_update_resource` / `stackgen-mcp_delete_resource` — snapshot first: `stackgen-mcp_create_snapshot`  

## 4. Terraform blocks on topology

- `stackgen-mcp_get_appstack_tf_*` / `stackgen-mcp_create_appstack_tf_*` / `stackgen-mcp_update_appstack_tf_*` / `stackgen-mcp_delete_appstack_tf_*` (variables, locals, outputs, providers)  

## 5. Env, runs, evidence

- `stackgen-mcp_get_env_profiles` / `stackgen-mcp_create_env_profile` / `stackgen-mcp_update_env_profile`  
- `stackgen-mcp_create_appstack_action_run` — Plan \| Apply \| Destroy  
- `stackgen-mcp_get_action_run` / `stackgen-mcp_get_action_run_logs`  
- `stackgen-mcp_get_snapshots` / `stackgen-mcp_create_snapshot` / `stackgen-mcp_restore_snapshot`  
- `stackgen-mcp_detect-drift` — verify exact hyphenated tool name in discovery  
- `stackgen-mcp_download-iac` — evidence tarball to a path  

## 6. Git export (when policy allows)

- `stackgen-mcp_list-available-secrets`  
- `stackgen-mcp_add-git-configuration` / `stackgen-mcp_list-git-configuration`  
- `stackgen-mcp_push-appstack-to-git`  

## 7. Governance & modules

- `stackgen-mcp_get_current_violations`  
- `stackgen-mcp_get_policies` / `stackgen-mcp_get_stackgen_policy_schema`  
- `stackgen-mcp_get_module_versions` / `stackgen-mcp_module_usage_in_appstacks`  
- `stackgen-mcp_get_scan_results` / `stackgen-mcp_scan_configuration` (confirm mutating scope before use)  

## 8. Provision shortcut

- `stackgen-mcp_provision_appstack` — optional path when org uses direct provision with `vars` / `environment`  

## 9. AWS outside StackGen graph

- Use **`aws_production`** (or configured cloud) integration **`run_shell`** + AWS CLI when MCP cannot reach live account APIs.

Always use **exact tool names** from the live integration (`search_tools`).
