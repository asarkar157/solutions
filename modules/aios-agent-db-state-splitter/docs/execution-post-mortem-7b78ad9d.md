# Execution post-mortem — trace `7b78ad9d62b240cca980c4723c81435b`

**Workflow run:** `wf-db-monorepo-state-split-convergence-019e7fcdf3c47eb5`  
**Date:** 2026-05-31  
**Outcome:** Workflow status `completed`; business outcome **failed** — `stage_summary:final-gate-and-memory=blocked:loop_not_finished`

## Input

- Monolith: 12,726 AWS resources (Google Drive tfstate)
- IaC repo: `https://github.com/sks/code-context-engine` branch `tfstates`
- StackGen project: `guild-demo`
- Result: 1,239 logical groups; large-state sample mode (20 groups)

## Stage results

| Stage | Result | Root cause |
|-------|--------|------------|
| `ingest-and-split` | Success | Script pack split + count reconcile OK |
| `split-loop-gate` | False `GO_BACK` | Loop gate iteration 0 missed `count_reconciliation_ok` in merged text |
| `split-ingest-blocked-gate` | Matched `GO_BACK` | Declared skip to final; downstream still ran (~46 min wasted) |
| `registry-and-import-codegen` | Blocked | `rsync: command not found` during IaC PR sync (stale sidecar / script) |
| `hcl-hydrate-per-group` | Max tool iterations | Lead architect probe thrash (51 subagents) vs batch fan-out |
| `materialize-stackgen-appstacks` | Max tool iterations | Payload extraction loops; no `stackgen_appstack_membership_report` |
| `multi-shard-plan-convergence` | Max tool iterations | Never emitted `multi_plan_zero_diff_ok` |
| `final-gate-and-memory` | Blocked | Correct evidence gate — loop not converged |

## Primary blockers (fix order)

1. **IaC PR sync** — use `cp -a` only in script pack (no `rsync` dependency); redeploy Ubuntu integration image.
2. **Ingest loop gates** — remove false `GO_BACK` path; single `ingest-blocked-gate` without `"action":"GO_BACK"` match.
3. **Architect thrash** — script-driven `prepare-parallel-artifacts` + `hydrate-and-plan-matrix`; coordinators spawn batch children in one turn only.
4. **HCL hydration** — post-process AWS `name` / `name_prefix` conflicts in `generated.tf` (observed on `aws-group-009`).

## DAG refactor (20260531.20+)

See module README **Workflow shape** — collapsed to 7 stages: ingest → ingest-blocked-gate → registry → 3-way parallel (`shell-converge-matrix` ‖ `materialize-appstacks-coordinator` ‖ `orphans-secondary-pipeline`) → final-gate.

## Follow-up post-mortem — trace `88b0393cd2c648549a8574a547b44e9a` (20260531.21)

**Workflow run:** `wf-db-monorepo-state-split-convergence-019e8011a00a718a`  
**Outcome:** Ingest blocked — `blocked:three_runner_attempts_failed` / `blocked:ingest_script_pack_failed`

| Attempt | Duration | Root cause |
|---------|----------|------------|
| 1 | ~24 min (900s timeout) | Google Drive download + 12,726-resource split exceeded `script_runner_timeout_seconds=900`; subagent hit TIME LIMIT before handoff |
| 2 | ~6 min | `execute_series` likely succeeded on disk (`notes.json` had keys) but runner parsed **stdout** → empty `count_reconciliation_ok=` / `logical_group_count=` (output truncation) |

**Fixes in `20260531.21`:**

1. **`script_runner_timeout_seconds` → 3600** (module default + guild `subagent_budgets` override).
2. **`$WORK_ROOT/.work/ingest-handoff.txt`** — compact key=value file written by script pack; runner `note()`s from file/`notes.json`, not stdout.
3. **Spawn contract goal** — forbid pasting stage note into `create_agent` goal (trace `88b0393c`: truncated goal dropped INGEST_EXECUTE_SERIES).
4. **SOP** — removed stale `gh api` fetch prose; documents base64 embed only.

## Follow-up post-mortem — trace `8c7ea4ade49c4ee1a391c5e7cc3493bb` (20260531.22)

**Workflow run:** `wf-db-monorepo-state-split-convergence-019e802b5b1c7d77`  
**Outcome:** Ingest failed — `count_reconciliation_ok=false`, `logical_group_count=unknown`; architect misdiagnosed as “embed not injected”

| Signal | Observed |
|--------|----------|
| `execute_series` latency | **~14s** (too fast for Drive download + 12k+ split) |
| Disk artifacts | No `notes.json`, no `.work/ingest-handoff.txt` under workflow work root |
| Series command | INGEST embed pasted **without** `export MONOLITH_URI` → immediate `error=MONOLITH_URI_unset` |
| Runner recovery | `cat ingest-handoff.txt` / `jq notes.json` both **No such file** |

**Root cause class:** **URI export omitted** — distinct from `88b0393c` (timeout / stdout truncation when script actually ran).

**Fixes in `20260531.22`:**

1. **Embed** — `dbsplit_resolve_monolith_uri()` reads `.work/spawn_monolith_uri`, `notes.json`, env, and `{{stage_note_var:monolith_state_uri}}` before preflight guard.
2. **Spawn contract** — mandatory `execute_command` pre-write of URI to `.work/spawn_monolith_uri` before pasting INGEST_EXECUTE_SERIES.
3. **`stage-runner.sh`** — `ensure_monolith_uri_from_work_root` at `ingest-and-split` entry.
4. **SOP / stage note** — FAIL signature: fast series + missing handoff → URI pre-write, not missing embed.

## Re-run verification (operator checklist)

After merging the module changes:

1. **Apply module** — `tofu apply` (or `terraform apply`) the `aios-agent-db-state-splitter` root so Guild receives the new workflow DAG, stage bindings, spawn contracts, and script pack version **`20260531.22`**.
2. **Ubuntu integration** — rebuild/deploy `stackgen-guild` Ubuntu CLI image (includes OpenTofu + optional `rsync`; script pack uses `cp -a` only). Confirm sidecar has script pack via a smoke `preflight` if upgrading in place.
3. **Re-trigger workflow** — same inputs as this run (`monolith_state_uri` / `tfstate_file`, `iac_repository_url`, `stackgen_project_name=guild-demo`). Expect full re-ingest **~20–40 min** for 12k+ resource Drive states (was failing at 15m timeout).
4. **Assert success signals:**
   - `pr_url` set (or explicit `pr_blocker` with `working_branch`)
   - `batch_payloads_path` and `large_state_sample_group_ids` present after registry stage
   - `multi_plan_zero_diff_ok: "true"` on sample 20 groups
   - `stackgen_appstack_membership_report` with `"partial": true` when `large_state_sample_mode=true`
   - `stage_summary:final-gate-and-memory=ok` and evidence checklist submitted
5. **Target wall time:** ~15–20 min end-to-end in large-state sample mode (vs ~46 min failed run).
