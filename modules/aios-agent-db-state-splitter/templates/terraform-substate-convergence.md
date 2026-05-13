Skill: **Count reconciliation** and **multi-shard plan matrix** until plans are empty — implements user checks *total count = monorepo total* and *0 changes across all sub-TFstates*.

Keywords: tofu plan -json, plan file, aggregate counts, drift, loop, workspace, backend.

## Count check

1. Recompute from **live** shard manifests (not cached notes if `convergence_iteration` changed):
   - `aggregate_shard_resource_count` vs `monolith_resource_count`.
2. If not equal → **fail this gate**, set `count_reconciliation_ok=false`, document missing/duplicate addresses, and stop before claiming success.

## Plan matrix

1. For each **logical group** Terraform root under `repo_clone_path` (or dedicated workdir — if the default tree is read-only, use a writable path under **`/tmp`** and align with orchestration SOP **`note`** keys), run:
   - `tofu init -backend=false -input=false` (or real backend when safe)
   - `tofu plan -no-color -input=false` (add `-lock=false` only if org policy allows)
2. When **`stackgen_appstack_map`** is populated, for each AppStack run **`create_appstack_action_run`** with `action_type` = **Plan** (StackGen MCP) and confirm success; optionally **`download-iac`** into the Ubuntu sandbox and run `tofu plan` on the download for cross-check.
3. Collect exit codes and whether each plan contains **no** create/change/destroy (parse `-json` if available).
4. Set `multi_plan_zero_diff_ok=true` only if **all** group TF roots **and** all StackGen plans (when in scope) pass.

## Looping

- If count fails → go back to **shard extraction / graph allocation** (per orchestration SOP Loop A).
- If count passes but any plan fails → go back to **registry / import / moved** alignment (Loop B).
- Persist `convergence_iteration` and short diff snippets (last 80 lines per shard) under `plan_failure_excerpts`.

## Remote execution

When org tooling allows **remote runner** fan-out, run shard plans in parallel there; else sequential Ubuntu CLI with `ubuntu-cli_execute_parallel` for independent shards only after `init` succeeded per shard.
