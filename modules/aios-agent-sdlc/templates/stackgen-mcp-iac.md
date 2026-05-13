Skill: **StackGen user MCP** for SDLC **cloud_infra** and developer-intake flows (`stackgen-mcp_*` tool prefix on your integration).

Full catalog: **`stackgen-mcp-consumer-tool-catalog-sop`** in `aios-agent-repo-to-iac` (aligned with the **AppStack / integrations** MCP at URLs such as **`…/api/mcp/user`**). This runbook is the **condensed operator chain** for greenfield + brownfield requests. **`search_tools`** is authoritative if your org exposes extra tools.

## 1. Context & inventory

- `stackgen-mcp_me` — org / caller scope  
- `stackgen-mcp_get_appstacks` — list stacks; `labels: ["template"]` for templates  
- `stackgen-mcp_get_appstack_resources` — what is on a stack  
- `stackgen-mcp_get_supported_resource_types` — **resource pack UUIDs** + allowed `resource_type` strings  

## 2. Greenfield canvas

- `stackgen-mcp_create_appstack` — optional `appstack_ref_id` from template  
- `stackgen-mcp_add_resource_to_appstack` — valid **`identifier`** (lowercase snake); correct **`resource_type`**  
- `stackgen-mcp_add_resource_pack_to_appstack` — **UUID only** for pack id  
- `stackgen-mcp_get_possible_resource_connections` → `stackgen-mcp_connect_resources`  

## 3. Brownfield from Terraform / state (primary)

- Map live addresses → **`stackgen-mcp_add_resource_to_appstack`** / **`stackgen-mcp_update_resource`** with snapshots: `stackgen-mcp_create_snapshot` first on risky paths  
- **Do not** assume discovery-import MCP (`list_cloud_discoveries`, `create_appstack_from_discovered_resources`) exists on the user MCP  

## 4. Terraform blocks on topology

- `stackgen-mcp_get_appstack_tf_*` / `stackgen-mcp_create_appstack_tf_*` / `stackgen-mcp_update_appstack_tf_*` / `stackgen-mcp_delete_appstack_tf_*` (variables, locals, outputs, providers)  

## 5. Env, runs, evidence

- `stackgen-mcp_get_env_profiles` / `stackgen-mcp_create_env_profile` / `stackgen-mcp_update_env_profile` / `stackgen-mcp_delete_env_profile`  
- `stackgen-mcp_create_appstack_action_run` — Plan \| Apply \| Destroy  
- `stackgen-mcp_get_action_run` / `stackgen-mcp_get_action_run_logs`  
- `stackgen-mcp_get_snapshots` / `stackgen-mcp_create_snapshot` / `stackgen-mcp_restore_snapshot`  
- `stackgen-mcp_get_current_violations`  

## 6. Git / module / policy tools

- **Not on user MCP:** `download-iac`, `detect-drift`, git-export tools, `get_module_versions`, `get_policies`, `provision_appstack`, etc. Use **StackGen Export**, **Ubuntu + GitHub**, or a **separate** MCP integration your platform team documents.

## 7. AWS outside StackGen graph

- Use **`aws_production`** (or configured cloud) integration **`run_shell`** + AWS CLI when MCP cannot reach live account APIs.

Always use **exact tool names** from the live integration (`search_tools`).
