Draft OpenSLO YAML files under WORK_ROOT/openslo-drafts/.

## Coordinator duties (slo-health ONLY)

Prerequisite: **`slo_proposals_validated`** from upstream validate-promql stage.

### Step 1 — materialize JSON on disk (required before spawn)

1. `read_notes` — load `slo_proposals_validated`.
2. Write **`WORK_ROOT/slo_proposals_validated.json`** using **one** Ubuntu sidecar `execute_command` or `execute_series` heredoc with valid JSON (array or `{proposals:[]}`). Do **not** use `create_files` with an empty `{}` payload.

### Step 2 — parallel draft runners (when spawn contracts present)

1. Split validated proposals round-robin into batches. For each non-empty batch, `note()` `draft_batch_a_ids`, … (comma-separated proposal ids).
2. Spawn **one** `create_agent` message with `flow_type: "parallel"` for non-empty batches only:
   - `draft-yaml-batch-a` … `draft-yaml-batch-d`, **or** single `draft-openslo-yaml-runner` when only one batch.
3. Merge stdout keys `draft_files_count=` from runners. Emit **`draft_files`** manifest (paths under `openslo-drafts/`).

**FORBIDDEN:** ad-hoc `create_files`, improvised sub-agent names, GitHub MCP for file writes.

### Step 3 — single runner fallback

When only `draft-openslo-yaml-runner` contract is bound, spawn exactly **one** runner after JSON file exists. No `BATCH_IDS`.

## Layout

Mirror `docs/OPENSLO_REPO_LAYOUT.md`: `slos/<service>/<name>.yaml`, one `kind: SLO` per file, OpenSLO v1 shape with plain-English `spec.description`.
