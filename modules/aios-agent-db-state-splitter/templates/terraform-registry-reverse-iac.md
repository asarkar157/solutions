Skill: **Reverse-engineer IaC** from allocated state slices and **best-fit map** to the org module registry (AIOS / internal catalog) and **StackGen resource types**.

Keywords: import block, terraform import, moved block, module registry, stackgen mcp, get_supported_resource_types, github.com/appcd-dev/solutions, aios-foundation, brownfield, codegen, aws, azure, gcp.

## Stage entry — `read_notes`, do not ask the operator

This stage runs **after** ingest / discover / allocate / count-reconcile. Always start with **`read_notes`** for:

- **`repo_clone_path`** — writable Ubuntu path, normally under `/tmp/db-state-split-<workflow_id>/repo`.
- **`monolith_state_local_path`** — downloaded `terraform.tfstate` (or `terraform show -json` snapshot).
- **`logical_group_manifest`** (or legacy `shard_manifest`) — `group_id -> { cloud_hint, resource_addresses[] }`.
- **`count_reconciliation_ok`** — must be `"true"`; if not, do **not** start this stage.

**Never `notify` the operator** for those values. If `read_notes` returns nothing, recover under `/tmp/db-state-split-<workflow_id>/` and re-run the upstream procedure (re-clone repo, re-download state, re-run shard extraction) before any escalation. AppStack materialization is the **next** stage — this stage produces TF roots, import/moved blocks, and `registry_mapping_report` only; do not ask whether StackGen MCP is attached.

## Execution (Ubuntu + large states)

- All **`terraform show -json`**, generated **`import`** / **`moved`** snippets, and **`groups/<group_id>/`** trees live on **Ubuntu CLI** under a **writable** tree — default **`/tmp/db-state-split-.../`** per **db-state-split-orchestration-sop** if the sandbox root is read-only.  
- **Chunk** work by `group_id` (or by cloud): one bounded **`ubuntu-cli_execute_series`** per slice — avoid one shell invocation that streams the entire monolith JSON back through the agent (timeouts and truncation). Per **db-state-split-orchestration-sop** § *Execution Optimization Protocol*, multi-step shell work is **always** one `execute_series` — never N concurrent `ubuntu-cli_execute_command` calls in the same turn. `ubuntu-cli_execute_command` is reserved for a single cohesive command; `ubuntu-cli_execute_parallel` (or `flow_type:"parallel"` subagent batches) is the only sanctioned way to fan out independent work.  
- Prefer **`ubuntu-cli_create_files`** for generated HCL/scripts, then short **`execute_series`** steps that reference the script path.

## Reverse IaC

1. For each `group_id` in `logical_group_manifest`, materialize a **root module** directory `groups/<group_id>/` (or `shards/<group_id>/`) with:
   - `versions.tf`, `providers.tf` matching monolith constraints.
   - `import {}` blocks (Terraform 1.5+) **or** scripted `terraform import` with recorded addresses.
2. Prefer **import blocks** generated from state attributes (`terraform show -json` per-address slice).
3. Capture `reverse_iac_summary`: files created, imports pending, known gaps.

## HCL hydration (mandatory — no human "HCL author" handoff)

`tofu plan` in a per-group root will report `N to add` (and never converge to "No changes") whenever a `resource "X" "Y" {}` body is **missing or empty**. Do **not** leave 402 (or any) stub `main.tf` files for a human to fill in. Hydrate them in two passes per group, both Ubuntu CLI:

1. **Pass 1 — generate config from import blocks.** In `groups/<group_id>/` (writable, under `/tmp/...` if needed):

   ```bash
   tofu init -input=false -no-color
   tofu plan \
     -generate-config-out=generated.tf \
     -input=false -lock=false -no-color \
     -out=hydrate.tfplan
   ```

   This is the **first-class** OpenTofu / Terraform 1.5+ flow for adopting existing resources: every `import { to = aws_X.foo, id = "..." }` block whose `to` address has **no** matching resource body is materialized into `generated.tf` (resource attributes are read from the live cloud or from the state if the backend is wired). Treat the `generated.tf` output as authoritative HCL for that group and **commit it next to the stubs**.

2. **Pass 2 — verify zero diff.** After `generated.tf` exists:

   ```bash
   tofu plan -input=false -lock=false -no-color -out=verify.tfplan
   ```

   Expected: `No changes. Your infrastructure matches the configuration.` (exit 0). If non-empty, classify the remaining diff:
   - **Attribute drift** (resource declared but value differs) → patch the generated body with the correct value from `terraform show -json` or accept the cloud value if it is canonical.
   - **`import` failures** (provider could not read the resource — IAM, region, deleted) → move the address to `orphans_bundle` with `reason: "import_failed_<provider_message>"`.
   - **Missing provider config** → add the provider block (region, project, subscription) to `providers.tf` and re-run.

3. **Persist hydration status:** for each `group_id`, write **`hcl_hydration_status:<group_id>`** as JSON `{ generated_tf_path, generated_resources, plan_no_changes: true|false, remaining_actions: { add, change, destroy }, attempt: 1|2|3 }`. The materialization gate and final gate read this — a group with `plan_no_changes=false` is **not** complete.

4. **Loop, do not handoff.** If pass 2 still has `change/destroy` actions, **stay in this stage** for that group: re-run pass 1 (Terraform's generator is incremental — it re-uses existing bodies) and patch deltas, until either `plan_no_changes=true` or the remaining addresses are moved to `orphans_bundle`. Never `notify` the operator with "please author HCL"; the workflow is the HCL author.

### Anti-pattern

- Writing `resource "aws_X" "Y" {}` (empty body) and declaring the stage complete. That is exactly the failure mode that produced `iteration 2` blocking item "Author resource blocks in all 402 main.tf stubs". Use `-generate-config-out` instead.
- Writing `*.tf.json` (Terraform JSON syntax) for any per-group root or scaffold file. See **HCL-only output** below.

## HCL-only output (never `.tf.json`)

Every file the workflow writes under `groups/<group_id>/` MUST be **HCL** with a `.tf` extension. This applies to:

- **Scaffold files** — `versions.tf`, `providers.tf`, `imports.tf` (or per-cloud `imports-aws.tf` / `imports-azure.tf` / `imports-gcp.tf`). Use HCL `terraform { required_providers { ... } }` + `provider "..." { ... }` blocks, **not** `terraform.tf.json` envelopes.
- **Import blocks** — Terraform 1.5+ `import {}` HCL blocks (`import { to = aws_s3_bucket.foo, id = "..." }`), **not** a JSON config map.
- **Generated bodies** — `generated.tf` from `tofu plan -generate-config-out=generated.tf`. The flag literally writes HCL; do not redirect it through `jq` / `tofu show -json` into a `*.tf.json` file.

Hard rules:

1. **No `*.tf.json` filenames** anywhere in the per-group root, even as "easier-to-template" placeholders. The `hcl_hydration_status:<group_id>` evidence schema records `generated_tf_path` which must end in `.tf`.
2. **`tofu fmt`** is the parity check — run it on every group root after scaffold + after hydration. JSON-syntax files fail `tofu fmt` cleanly, which is why this rule is enforceable downstream.
3. **State JSON stays in scratch.** `terraform show -json` / `tofu show -json` output (`*.state.json`, `*.plan.json`) lives under `/tmp/db-state-split-<workflow_id>/` and is **never** committed alongside the per-group `.tf` files. Treat that output as *parser input*, not Terraform configuration.
4. **`jq`-built JSON is not Terraform config.** Do not synthesize `*.tf.json` via `jq` / `python -c json.dumps` even when an attribute is awkward in HCL. If a value is genuinely unrepresentable, push the address to `orphans_bundle{reason:"requires_dynamic_codegen"}` for `orphan-iac-module-authoring` to wrap in HCL.

## StackGen module / template cross-check

The StackGen **user** MCP (`…/api/mcp/user`) does **not** expose Terraform module catalog tools (`get_module_versions`, `module_usage_in_appstacks`). For **StackGen** alignment use **`get_supported_resource_types`**, **`get_resource_type_configurations`**, and **`get_appstacks`** (e.g. `labels: ["template"]`) plus **`get_appstack_resources`** on candidate templates. For **Terraform** module sources (AIOS `github.com/appcd-dev/solutions`, pins, double-slash paths), use **Ubuntu CLI** + `git` / registry browser patterns in this runbook — not MCP module-metadata calls unless a **different** integration provides them.

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
