Skill: **StackGen user MCP — tool catalog** for repository-to-IaC, AppStack materialization, env profiles, plans, and snapshots. Documents the **integrations / AppStack** MCP surface (e.g. **`https://<host>/api/mcp/user`** with Bearer auth). Use **exact tool names** from the agent’s live tool list (`search_tools`) — Guild prefixes with **`<integration>_<tool>`** (hyphens in the integration name are preserved).

Keywords: create_appstack, add_resource_to_appstack, connect_resources, get_appstacks, create_appstack_action_run, create_env_profile, snapshots, get_current_violations.

## Guild naming

The MCP server registers tools with **underscore base names** (e.g. `create_appstack`, `get_appstack_resources`). Guild often exposes them as **`<integration_name>_<tool>`** where the integration name may contain hyphens (e.g. `stackgen-mcp_create_appstack`). **Always match the prefix your integration uses** — do not guess; discover at runtime with **`search_tools`**.

Other StackGen deployments **may** register additional tools (policies, git export, discovery import, `download-iac`, etc.). This catalog lists only tools verified on the **user** AppStack MCP — if your `search_tools` output differs, **trust the live list**.

---

## Full tool matrix (user MCP)

| Base name | Role |
|-----------|------|
| `me` | Caller / org context; pair with workflow `stackgen_project_name` (UUID) for `project_name` on other calls |
| `get_appstacks` | List/filter stacks; `labels: ["template"]` for template UUIDs |
| `create_appstack` | `name`, `project_name` (UUID), optional `cloud_provider`, `description`, `labels`, `appstack_ref_id` (template) |
| `get_appstack_resources` | Inventory resources on a stack |
| `add_resource_to_appstack` | `resource_type`, `identifier` (lowercase snake per server rules), optional `resource_template_id` |
| `add_resource_pack_to_appstack` | **`resource_pack_id` must be UUID** from `get_supported_resource_types` — never a display name |
| `delete_resource` | Remove a resource from a stack |
| `update_resource` | Brownfield config edits |
| `get_supported_resource_types` | Allowed `resource_type` strings + **resource pack UUIDs** |
| `get_resource_type_configurations` / `get_resource_configurations` | Read config schema / values |
| `get_possible_resource_connections` | Discovery for wiring |
| `connect_resources` | Wire source output → target input |
| `create_appstack_tf_providers` / `create_appstack_tf_variables` / `create_appstack_tf_locals` / `create_appstack_tf_outputs` | Author TF fragments on the topology |
| `get_appstack_tf_providers` / `get_appstack_tf_variables` / `get_appstack_tf_locals` / `get_appstack_tf_outputs` | Read TF blocks |
| `update_appstack_tf_provider` / `update_appstack_tf_variable` / `update_appstack_tf_local` / `update_appstack_tf_output` | Update TF blocks |
| `delete_appstack_tf_provider` / `delete_appstack_tf_variable` / `delete_appstack_tf_local` / `delete_appstack_tf_output` | Delete TF blocks |
| `get_env_profiles` / `create_env_profile` / `update_env_profile` / `delete_env_profile` | Env profiles; `create_env_profile` needs **`profile_name`**; **`topology_id` if `appstack_name` absent**; optional `state_backend_raw_hcl` |
| `create_appstack_action_run` | `action_type`: Plan \| Apply \| Destroy |
| `get_action_run` / `get_action_run_logs` | Evidence |
| `create_snapshot` / `get_snapshots` / `restore_snapshot` | Point-in-time |
| `get_current_violations` | Policy violations signal |

**Not on user MCP:** `list_cloud_discoveries`, `get_resources_from_discovery`, `create_appstack_from_discovered_resources`, `download-iac`, `detect-drift`, `get_stackgen_projects`, git-export tools (`add-git-configuration`, `push-appstack-to-git`, …), `get_module_versions`, `module_usage_in_appstacks`, `get_policies`, `provision_appstack`, `get_scan_results`, etc. Use **Ubuntu/GitHub** for module registry research, **StackGen Export** (product) for git delivery when MCP git tools are absent, or a **separate** MCP integration your org provides.

---

## Ordering (typical repo-scan → plan → export)

1. `me` + resolve **`project_name`** UUID (from workflow / notes).
2. `get_supported_resource_types` + template discovery via `get_appstacks` (`labels: ["template"]` when needed).
3. `create_appstack` → `add_resource_to_appstack` / packs → `get_possible_resource_connections` → `connect_resources`.
4. `create_env_profile` / `update_env_profile` as needed.
5. `create_appstack_action_run` (Plan) → `get_action_run` / `get_action_run_logs`.
6. Optional: `create_snapshot` after green state.
7. **Export to Git:** use StackGen product **Export** (or org-specific automation). Do **not** assume `push-appstack-to-git` exists on this MCP.

## Anti-patterns

- **Resource pack name** instead of UUID on `add_resource_pack_to_appstack`.
- **Invalid `identifier`** on `add_resource_to_appstack`.
- Assuming tool prefix — **read the attached integration’s tool list**.
