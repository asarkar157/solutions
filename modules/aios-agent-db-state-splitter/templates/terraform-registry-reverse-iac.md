Skill: **Reverse-engineer IaC** from allocated state slices and **best-fit map** to the org module registry (AIOS / internal catalog) and **StackGen resource types**.

Keywords: import block, terraform import, moved block, module registry, stackgen mcp, get_module_versions, github.com/appcd-dev/solutions, aios-foundation, brownfield, codegen, aws, azure, gcp.

## Execution (Ubuntu + large states)

- All **`terraform show -json`**, generated **`import`** / **`moved`** snippets, and **`groups/<group_id>/`** trees live on **Ubuntu CLI** under a **writable** tree — default **`/tmp/db-state-split-.../`** per **db-state-split-orchestration-sop** if the sandbox root is read-only.  
- **Chunk** work by `group_id` (or by cloud): one bounded **`ubuntu-cli_execute_series`** / command batch per slice — avoid one shell invocation that streams the entire monolith JSON back through the agent (timeouts and truncation).  
- Prefer **`ubuntu-cli_create_files`** for generated HCL/scripts, then short **`execute_series`** steps.

## Reverse IaC

1. For each `group_id` in `logical_group_manifest`, materialize a **root module** directory `groups/<group_id>/` (or `shards/<group_id>/`) with:
   - `versions.tf`, `providers.tf` matching monolith constraints.
   - `import {}` blocks (Terraform 1.5+) **or** scripted `terraform import` with recorded addresses.
2. Prefer **import blocks** generated from state attributes (`terraform show -json` per-address slice).
3. Capture `reverse_iac_summary`: files created, imports pending, known gaps.

## StackGen module / template cross-check

Use MCP **`get_module_versions`** (filter `cloud_provider`, `module_resource_type`, `project_id`) and **`module_usage_in_appstacks`** to see how similar modules are already used before proposing new custom types. Prefer existing **templates** (`get_appstacks` with `labels: ["template"]`) + `create_appstack` with `appstack_ref_id` when they fit a whole group.

## Registry best-fit (AIOS-oriented inventory — align versions with consumer)

Match group resource patterns to published modules (double-slash Git source in real roots):

| Pattern | Likely module / layer |
|---------|------------------------|
| LLM keys, models, vault secrets | `modules/aios-foundation` |
| Org-wide Rego policies | `modules/aios-policies` |
| AWS account integration | `modules/aios-integration-aws` |
| DB cost / optimization agents | `modules/aios-agent-db-optimizer` (workflows + policies) |
| GitHub / Slack / Grafana integrations | `modules/aios-integration-github`, `aios-integration-slack`, `aios-integration-grafana` |
| Schedules | `modules/aios-agent-schedules` |

When a subgraph fits an existing **data** module, pin `source` + `ref` and replace hand-written duplicates. When **no** Terraform module fits but a **StackGen resource_type** exists, record the mapping for **`add_resource_to_appstack`**. When nothing fits, add the address list + rationale to **`orphans_bundle`** for the secondary pipeline.

## Output

- `registry_mapping_report` (markdown): columns `group_id`, `suggested_module` / `stackgen_resource_type`, `confidence`, `actions`.
- Update `orphans_bundle` with `{address, reason, suggested_new_module_name}`.
