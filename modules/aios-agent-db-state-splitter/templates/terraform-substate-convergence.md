Skill: **Count reconciliation** and **multi-shard plan matrix** until plans are empty — implements user checks *total count = monorepo total* and *0 changes across all sub-TFstates*.

Keywords: tofu plan -json, plan file, aggregate counts, drift, loop, workspace, backend.

## Count check

1. Recompute from **live** shard manifests (not cached notes if `convergence_iteration` changed):
   - `aggregate_shard_resource_count` vs `monolith_resource_count` using the **same rules** as ingest (managed instances only unless you explicitly counted `data.*`; **`deposed`** / excluded rows must match both sides).
2. If not equal → **fail this gate**, set `count_reconciliation_ok=false`, document missing/duplicate addresses, and stop before claiming success.

## Membership pre-check (StackGen)

Before any **`create_appstack_action_run`** Plan, verify the AppStack actually contains the group's expected resources. Read **`stackgen_appstack_membership:<group_id>`** for every `group_id` in `logical_group_manifest`:

- All entries must exist with `ok=true`. A missing entry means materialization never verified that group — go back to **stackgen-appstack-mcp-playbook-sop** step 3.5 for that group.
- `expected_count` must equal `len(group.resource_addresses)` and `actual_count` must equal `expected_count`.
- `cross_group_bleed` must be empty.
- Stop and escalate via `notify` if any of these fail; do **not** call `create_appstack_action_run` for a stack whose membership is wrong — the Plan will mislead operators.

## Plan matrix

1. For each **logical group** Terraform root under `repo_clone_path` (or dedicated workdir — if the default tree is read-only, use a writable path under **`/tmp`** and align with orchestration SOP **`note`** keys), run:
   - `tofu init -backend=false -input=false` (or real backend when safe)
   - `tofu plan -no-color -input=false` (add `-lock=false` only if org policy allows)
2. **StackGen Plan is OPTIONAL.** When **`stackgen_appstack_map`** is populated **and** the membership pre-check passed **and** `stackgen_env_profile:<group_id>` is **not** marked `skipped`, run **`create_appstack_action_run`** with `action_type` = **Plan** per AppStack and capture evidence with **`get_action_run`** / **`get_action_run_logs`**. Skip silently for groups whose `stackgen_env_profile:<group_id>` is `{ skipped: "no_target_env_input" | "env_missing_in_project_settings" }` and rely on Ubuntu `tofu plan` parity for those — the user MCP does not expose **`download-iac`**.
3. Collect exit codes and whether each plan contains **no** create/change/destroy (parse `-json` if available).
4. Set `multi_plan_zero_diff_ok=true` when **all** per-group TF roots pass; StackGen Plans only contribute to the gate when they were actually run (groups with `stackgen_plan_run:<group_id>.skipped` are excluded from the StackGen side of the AND).

### Timeouts and chunking (Ubuntu + traces)

Integration shells often hit **~300s** ceilings. A single long **`ubuntu-cli_execute_command`** that runs `init` + `plan` for every shard in one shot is a common source of **timeout-shaped failures** in DAG exports.

- **One shard per shell step** (or a small fixed batch) with a conservative **`timeout_seconds`** per command; persist plan logs under your **`/tmp/...`** workdir and **`note`** paths to excerpts.  
- Prefer **`ubuntu-cli_execute_series`** with **short** steps over one megacommand.  
- When **`remote_runner_name`** is configured on the module, **fan out** heavy `plan` / `terraform show -json` there (see **`db-state-split-orchestration-sop`**) instead of wedging everything through one Ubuntu session.

## Looping

- If count fails → go back to **shard extraction / graph allocation** (per orchestration SOP Loop A).
- If count passes but any plan fails → go back to **registry / import / moved** alignment (Loop B).
- Persist `convergence_iteration` and short diff snippets (last 80 lines per shard) under `plan_failure_excerpts`.

## Remote execution

When org tooling allows **remote runner** fan-out, run shard plans in parallel there; else sequential Ubuntu CLI with `ubuntu-cli_execute_parallel` for independent shards only after `init` succeeded per shard.

## Workflow DAG (db-monorepo-state-split-convergence)

Guild runs **independent stages in the same topological layer in parallel**. After reverse IaC + registry mapping, **AppStack materialization** and **orphan secondary handoff** are in one layer; **`multi-shard-plan-convergence`** waits for **both** (fan-in) before the plan matrix. See **db-state-split-orchestration-sop** for the full graph and note-key hygiene when stages overlap in time.
