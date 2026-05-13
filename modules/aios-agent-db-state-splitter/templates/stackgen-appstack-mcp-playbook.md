Skill: **Materialize StackGen AppStacks** from Terraform/OpenTofu state groupings using the **StackGen MCP tools** (exact tool names below). Use for **AWS, Azure, and GCP** resources in the same monolith state.

Keywords: create_appstack, add_resource_to_appstack, connect_resources, create_appstack_from_discovered_resources, get_supported_resource_types, get_module_versions, environment profile, state backend, brownfield, multi-cloud.

## Preconditions

- Guild agent has the **StackGen MCP** integration attached (same pattern as `aios-agent-repo-to-iac`). For a **single canonical catalog** of Consumer MCP tools (including git export, policies, and modules), also load **`stackgen-mcp-consumer-tool-catalog-sop`** from the repo-to-iac module when composing stacks in the same org.
- Workflow notes must include `logical_group_manifest` (or legacy `shard_manifest`), `stackgen_project_name` / project UUID, and per-group inferred `cloud_provider` ∈ {`aws`,`azure`,`gcp`}.

## Tool catalog (StackGen MCP — use these names)

**Discovery (alternative to pure state grouping)**  
- `list_cloud_discoveries` — list org discoveries; filter by name/org.  
- `get_resources_from_discovery` — paginate resource IDs for a `discovery_id`.  
- `create_appstack_from_discovered_resources` — **Required:** `discovery_id`, `resources` (ID list from prior tool). Optional: `appstack_id` to append into existing stack, `data_sources`, `governance_id`, `org_id`.

**AppStack lifecycle**  
- `get_stackgen_projects` / `me` — resolve project UUID (`project_name` in many calls is the **project UUID** per tool schema).  
- `get_appstacks` — list/filter; use `labels: ["template"]` then pass template id as `appstack_ref_id` on `create_appstack` when you want a template-based stack.  
- `create_appstack` — **name**, **project_name** (UUID); optional `cloud_provider`, `description`, `labels`, `appstack_ref_id` (template UUID). Returns **`id`** (use as `appstack_name` in subsequent calls — schema labels this “UUID”).  
- `add_resource_to_appstack` — **resource_type** (e.g. `aws_ec2_instance`, `azurerm_linux_virtual_machine`, `google_compute_instance`), **identifier** (lowercase + underscores only), optional `resource_template_id` for custom modules.  
- `add_resource_pack_to_appstack` — **`resource_pack_id` must be a UUID** from `get_supported_resource_types` → resource packs section; **never** pass a human name.  
- `get_supported_resource_types` — discover allowed `resource_type` strings and pack UUIDs.  
- `get_possible_resource_connections` — then **`connect_resources`** to wire outputs→inputs (prefer connections over free variables).  
- `get_resource_configurations` / `get_resource_type_configurations` / `update_resource` — tune configs after add.

**IaC, env, drift, export**  
- `create_appstack_tf_providers` / `create_appstack_tf_variables` / `create_appstack_tf_locals` / `create_appstack_tf_outputs` — when editing generated topology HCL.  
- `create_env_profile` — **`profile_name` required**; **`topology_id` required if `appstack_name` not provided**; optional `state_backend_raw_hcl` for per-shard remote state.  
- `create_appstack_action_run` — `action_type`: Plan | Apply | Destroy; use **Plan** for convergence checks.  
- `detect-drift` — optional drift signal on a topology.  
- `download-iac` — **`appstack_id`**, **`destination`** directory; compare with Ubuntu-sandbox `tofu plan` for parity.  
- `add-git-configuration` + `push-appstack-to-git` — export to Git when `list-git-configuration` / secrets exist (`list-available-secrets`).

**Module registry (cross-check)**  
- `get_module_versions` — filter by `cloud_provider`, `module_resource_type`, `project_id`.  
- `module_usage_in_appstacks` — find existing usage of custom modules before inventing new types.

## Recommended flows

### Flow A — From Terraform state groups (primary for this workflow)

1. For each **logical group** in `logical_group_manifest` (see state-grouping SOP):  
   - Infer **one** `cloud_provider` from resource type prefixes (`aws_*`, `azurerm_*`, `google_*`, `azapi_*` → map to aws/azure/gcp heuristics). Mixed-provider groups → split group first.  
   - `create_appstack` with a stable sanitized **name** (`<repo>-<group_key>`), **labels** echoing source tags (e.g. `split-from:monolith`, `group:<key>`).  
2. For each resource address in the group, map Terraform type → StackGen **`resource_type`** via `get_supported_resource_types`; then `add_resource_to_appstack` with a unique **`identifier`**.  
3. `get_possible_resource_connections` → `connect_resources` for obvious edges (VPC→subnet→instance, server→database, etc.).  
4. `create_env_profile` with **per-AppStack state backend** HCL when splitting remote state.  
5. `create_appstack_action_run` (**Plan**) per AppStack; then optional `download-iac` with **`destination`** under a **writable** directory (prefer **`/tmp/.../stackgen-export/`** when `repo_clone_path` is read-only or missing); compare with Ubuntu-sandbox `tofu plan` for offline diff.

### Flow B — From existing StackGen cloud discovery

1. `list_cloud_discoveries` → pick `discovery_id`.  
2. `get_resources_from_discovery` (paginate) → partition IDs with the **same tag/module rules** as Flow A.  
3. One `create_appstack_from_discovered_resources` call **per** partition (or one appstack + multiple calls with `appstack_id` to append).  
4. Continue with env profiles + Plan as in Flow A.

## Persistence (notes)

- `stackgen_appstack_map` — JSON: `group_id -> { appstack_id, appstack_name, cloud_provider, project_name, plan_run_id? }`.  
- `stackgen_mcp_errors` — append-only log of tool failures + remediation.

## Anti-patterns

- Passing **resource pack name** to `add_resource_pack_to_appstack` (must be UUID).  
- Calling `add_resource_to_appstack` with invalid **`identifier`** (must be lowercase snake).  
- Running `terraform`/`tofu` **inside** MCP instead of Ubuntu CLI — keep CLI in Ubuntu MCP; keep StackGen API in StackGen MCP.
