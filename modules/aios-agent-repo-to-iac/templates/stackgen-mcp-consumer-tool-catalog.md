Skill: **StackGen Consumer MCP — full tool catalog** for repository-to-IaC, AppStack materialization, env/export, and discovery. Use **exact tool names** from the agent’s live tool list (`search_tools`).

Keywords: create_appstack, add_resource_to_appstack, connect_resources, download-iac, push-appstack-to-git, create_appstack_from_discovered_resources, list_cloud_discoveries, provision_appstack, detect-drift.

## Guild naming

The MCP server registers tools with **base names** (e.g. `create_appstack`, `download-iac`). Guild often exposes them as **`<integration_name>_<tool>`** where the integration name may contain hyphens (e.g. `stackgen-mcp_create_appstack`, `stackgen-mcp_download-iac`). **Always match the prefix your integration uses** — do not guess; discover at runtime.

---

## AppStack lifecycle

| Base name | Role |
|-----------|------|
| `me` | Caller / org context |
| `get_stackgen_projects` | Resolve project UUIDs |
| `get_appstacks` | List/filter; `labels: ["template"]` for template UUIDs |
| `create_appstack` | `name`, `project_name` (UUID), optional `cloud_provider`, `description`, `labels`, `appstack_ref_id` (template) |
| `get_appstack_resources` | Inventory resources on a stack |
| `add_resource_to_appstack` | `resource_type` (e.g. `aws_ec2_instance`, `azurerm_linux_virtual_machine`, `google_compute_instance`), `identifier` (**lowercase snake only**), optional `resource_template_id` for custom |
| `add_resource_pack_to_appstack` | **`resource_pack_id` must be UUID** from `get_supported_resource_types` — never a display name |
| `get_supported_resource_types` | Allowed `resource_type` strings + **resource pack UUIDs** |
| `get_possible_resource_connections` | Discovery for wiring |
| `connect_resources` | Wire source output → target input |
| `get_resource_configurations` / `get_resource_type_configurations` | Read config schema |
| `update_resource` / `delete_resource` | Brownfield edits (use snapshots before risky deletes) |

## Discovery → AppStack (brownfield cloud)

| Base name | Role |
|-----------|------|
| `list_cloud_discoveries` | Paginated org discoveries |
| `get_resources_from_discovery` | Resource IDs for a `discovery_id` |
| `create_appstack_from_discovered_resources` | **Required:** `discovery_id`, `resources` (ID list); optional `appstack_id` (append), `data_sources`, `governance_id`, `org_id` |

## Terraform surface on the topology

| Base name | Role |
|-----------|------|
| `create_appstack_tf_providers` / `create_appstack_tf_variables` / `create_appstack_tf_locals` / `create_appstack_tf_outputs` | Author HCL fragments |
| `get_appstack_tf_providers` / `get_appstack_tf_variables` / `get_appstack_tf_locals` / `get_appstack_tf_outputs` | Read current TF blocks |

## Env, runs, drift, IaC download

| Base name | Role |
|-----------|------|
| `get_env_profiles` / `create_env_profile` / `update_env_profile` / `delete_env_profile` | `create_env_profile`: **`profile_name` required**; **`topology_id` if `appstack_name` absent**; optional `state_backend_raw_hcl` |
| `create_appstack_action_run` | `action_type`: Plan \| Apply \| Destroy |
| `get_action_run` / `get_action_run_logs` | Evidence |
| `create_snapshot` / `get_snapshots` / `restore_snapshot` | Point-in-time |
| `detect-drift` | Drift signal (hyphenated name — check exact tool string) |
| `download-iac` | **`appstack_id`**, **`destination`** dir on runner/agent filesystem |

## Git export

| Base name | Role |
|-----------|------|
| `list-available-secrets` | Vault secret names/UUIDs for git auth |
| `add-git-configuration` | Tie appstack to `repo_url`, `secret_to_use`, optional `branch`, `path` |
| `list-git-configuration` | Existing export configs |
| `push-appstack-to-git` | Push topology IaC using a saved git config |

## Modules, policies, compliance (read-heavy)

| Base name | Role |
|-----------|------|
| `get_module_versions` | Module version metadata + Git import hints |
| `module_usage_in_appstacks` | Where custom modules are used |
| `get_policies` | Org policies |
| `get_stackgen_policy_schema` | Policy shape |
| `get_scan_results` | Template/module security scans |
| `scan_configuration` / `scan_custom_resource_template` | Compliance scans (may be mutating — confirm scope) |
| `validate_policy_format` / `upload_security_policy` | Policy authoring (mutating) |

## Other

| Base name | Role |
|-----------|------|
| `provision_appstack` | Drive provision with optional `apply`, `environment`, `vars` |
| `get_current_violations` | Policy violations on topology |
| `destroy_deployment` | **Destructive** — only with explicit approval |
| `create_custom_modules` / `delete_custom_modules` | Custom module ingestion |

## Ordering (typical repo-scan → export)

1. `me` → `get_stackgen_projects` / resolve `project_name` UUID  
2. `get_supported_resource_types` + template `get_appstacks`  
3. `create_appstack` → `add_resource_to_appstack` / packs → `get_possible_resource_connections` → `connect_resources`  
4. `create_env_profile` / updates  
5. `create_appstack_action_run` (Plan/Apply per policy) → logs  
6. `download-iac` for local verification when useful  
7. `add-git-configuration` + `push-appstack-to-git` toward target repo **or** product **Export** flow  

## Anti-patterns

- **Resource pack name** instead of UUID on `add_resource_pack_to_appstack`  
- **Invalid `identifier`** on `add_resource_to_appstack` (must match server rules)  
- Assuming tool prefix — **read the attached integration’s tool list**
