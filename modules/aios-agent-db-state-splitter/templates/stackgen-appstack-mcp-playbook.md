Skill: **Materialize StackGen AppStacks** from Terraform/OpenTofu state groupings using **StackGen user MCP** tools (the AppStack / integrations surface exposed at URLs such as **`…/api/mcp/user`**). Use for **AWS, Azure, and GCP** resources in the same monolith state.

Keywords: create_appstack, add_resource_to_appstack, connect_resources, get_supported_resource_types, get_appstacks, create_env_profile, create_appstack_action_run, get_action_run_logs, snapshots, get_current_violations.

## Preconditions

- Guild agent has the **StackGen MCP** integration attached (same pattern as `aios-agent-repo-to-iac`). For the **canonical tool matrix** shared with repo-to-iac flows, load **`stackgen-mcp-consumer-tool-catalog-sop`** from that module — it is aligned with the **user** MCP catalog (not every hypothetical StackGen extension).
- Workflow notes must include `logical_group_manifest` (or legacy `shard_manifest`), **project UUID** for StackGen calls (workflow input `stackgen_project_name` is usually that UUID — confirm with **`me`**), and per-group inferred `cloud_provider` ∈ {`aws`,`azure`,`gcp`}.
- **`search_tools`** on the live integration is authoritative if your org mounts a **different** MCP server with extra tools.

## List traffic and note cache (reliability + smaller traces)

DAGs from long runs often show dozens of **`get_appstacks`** / **`get_appstack_resources`** calls. That burns latency, hits rate limits, and duplicates spans in telemetry.

1. **One list pass per materialization wave** — call **`get_appstacks`** once (with the filters you need, e.g. `labels: ["template"]` when using templates), then **`note`** a compact JSON snapshot under **`stackgen_appstack_list_cache`** (`{ updated_at, stacks: [{ id, name, labels? }] }`).
2. **Per-stack resource listing** — call **`get_appstack_resources`** only for the `appstack_id` you are actively mutating, or immediately after **`create_appstack`** / append flows to verify membership — not before every **`add_resource_to_appstack`**.
3. **After mutations** — refresh **`stackgen_appstack_list_cache`** only when you create/delete/rename stacks or when a follow-up call returns a stale/not-found error.
4. **Do not** interleave **`search_skill`** / **`load_skill`** here; use this playbook + **`db-state-split-orchestration-sop`** (runbooks on the workflow).

## Tool catalog (StackGen user MCP — base names)

These names match the **integrations / AppStack** MCP server (`streamable_http` on **`…/api/mcp/user`**). Guild exposes them as **`<integration>_<tool>`** (e.g. `stackgen-mcp_create_appstack`).

**Identity**

- `me` — caller / org context; use with workflow notes / `stackgen_project_name` for **`project_name`** (UUID) on other calls.

**AppStacks & resources**

- `get_appstacks`, `get_appstack_resources`
- `create_appstack`
- `add_resource_to_appstack`, `add_resource_pack_to_appstack`, `update_resource`, `delete_resource`
- `get_supported_resource_types`, `get_resource_type_configurations`, `get_resource_configurations`
- `get_possible_resource_connections`, `connect_resources`

**Terraform blocks on the AppStack**

- `create_appstack_tf_providers`, `create_appstack_tf_variables`, `create_appstack_tf_locals`, `create_appstack_tf_outputs`
- `get_appstack_tf_providers`, `get_appstack_tf_variables`, `get_appstack_tf_locals`, `get_appstack_tf_outputs`
- `update_appstack_tf_provider`, `update_appstack_tf_variable`, `update_appstack_tf_local`, `update_appstack_tf_output`
- `delete_appstack_tf_provider`, `delete_appstack_tf_variable`, `delete_appstack_tf_local`, `delete_appstack_tf_output`

**Env profiles**

- `get_env_profiles`, `create_env_profile`, `update_env_profile`, `delete_env_profile`

**Action runs & evidence**

- `create_appstack_action_run`, `get_action_run`, `get_action_run_logs`

**Snapshots**

- `create_snapshot`, `get_snapshots`, `restore_snapshot`

**Policy signal**

- `get_current_violations`

**Not on this MCP surface (do not assume they exist):** cloud-discovery import (`list_cloud_discoveries`, `get_resources_from_discovery`, `create_appstack_from_discovered_resources`), **`download-iac`**, **`detect-drift`**, git-export helpers (`add-git-configuration`, `push-appstack-to-git`, `list-git-configuration`, `list-available-secrets`), Terraform module catalog (`get_module_versions`, `module_usage_in_appstacks`), org policy / scan APIs (`get_policies`, `get_scan_results`, …). Use **Ubuntu CLI** + GitHub for registry / git work, the StackGen product **Export** UI when exporting IaC, or attach another integration if your platform team exposes those tools elsewhere.

## Recommended flow — from Terraform state groups (primary)

1. For each **logical group** in `logical_group_manifest`: infer **one** `cloud_provider` from resource type prefixes (`aws_*`, `azurerm_*`, `google_*`, `azapi_*` → map to aws/azure/gcp heuristics). Mixed-provider groups → split the group first.
2. `create_appstack` with a stable sanitized **name** (`<repo>-<group_key>`), **labels** echoing source tags (e.g. `split-from:monolith`, `group:<key>`); optional **`appstack_ref_id`** from a template id discovered via `get_appstacks` + `labels: ["template"]`.
3. For each resource address in the group, map Terraform type → StackGen **`resource_type`** via `get_supported_resource_types`; then `add_resource_to_appstack` with a unique **`identifier`** (lowercase snake per server rules).
4. `get_possible_resource_connections` → `connect_resources` for obvious edges (VPC→subnet→instance, server→database, etc.).
5. `create_env_profile` / `update_env_profile` with **per-AppStack state backend** HCL when splitting remote state.
6. `create_appstack_action_run` with **`action_type`** = **Plan** per AppStack; use **`get_action_run`** / **`get_action_run_logs`** for evidence. For parity with Ubuntu `tofu plan`, diff **Terraform roots** you already materialized under **`repo_clone_path`** — there is **no** `download-iac` on this server.
7. Before risky deletes, use **`create_snapshot`**; use **`get_current_violations`** when debugging policy blocks.

### Optional workflow input `cloud_discovery_id`

If the workflow passes **`cloud_discovery_id`**, treat it as an **operator correlation id** only. This MCP server does **not** expose discovery-import tools; materialization stays **Flow A** (state → AppStack) unless you attach a **different** MCP integration that documents discovery import.

## Persistence (notes)

- `stackgen_appstack_map` — JSON: `group_id -> { appstack_id, appstack_name, cloud_provider, project_name, plan_run_id? }`.
- `stackgen_appstack_list_cache` — optional: last **`get_appstacks`** / resource listing snapshot + `updated_at` (see **List traffic and note cache** above).
- `stackgen_mcp_errors` — append-only log of tool failures + remediation.

## Anti-patterns

- Passing **resource pack name** to `add_resource_pack_to_appstack` (must be UUID from `get_supported_resource_types`).
- Calling `add_resource_to_appstack` with invalid **`identifier`** (must match server rules — typically lowercase snake).
- Running `terraform`/`tofu` **inside** MCP instead of Ubuntu CLI — keep CLI in Ubuntu MCP; keep StackGen API in StackGen MCP.
- Assuming **discovery import**, **`download-iac`**, or **git push** MCP tools exist on the default user MCP URL.
