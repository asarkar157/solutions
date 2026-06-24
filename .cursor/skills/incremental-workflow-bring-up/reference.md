# Incremental workflow bring-up — reference

Spec-symphony (`modules/aios-agent-spec-symphony`) is the reference workflow. Adapt paths for other `aios-agent-*` modules.

## File map (spec-symphony)

| File | Role in bring-up |
|------|------------------|
| `main.tf` | `sg_workflow` `stages` + `stage_bindings` — **trim here** |
| `spawn_contracts.tf` | Sub-agent goals + `execute_series` command templates (`{{work_root}}`) |
| `templates/stage-notes/*.md.tftpl` | Orchestrator per-stage instructions (blocker vs default path) |
| `scripts/stage-runner.sh` | Remote-runner subcommands (`clone`, `spec-bootstrap`, `commit-pr`, …) |
| `script_pack.tf` | Tarball b64 secret synced to runner; bump `script_pack_version` on script edits |
| `examples/scenarios/spec-symphony/` | Scenario root: `tofu apply`, `scripts/start-runner.sh`, `scripts/trigger-webhook.sh` |

## Stage order (spec-driven-feature)

```
intake-clone-bootstrap → repo-sdd-bootstrap → author-spec → implement
  → validate → create-pr → update-tracker
```

`stage_depends_on` must mirror this chain when re-adding bindings.

## Local iteration commands (spec-symphony scenario)

```bash
cd examples/scenarios/spec-symphony

tofu apply -auto-approve

docker rm -f spec-symphony-runner
./scripts/start-runner.sh --run

./scripts/trigger-webhook.sh --from-tofu-output \
  --repo stackgenhq/discovery-modules \
  --issue 67 \
  --title "CORE-101 Spec-symphony test $(date +%H%M%S)" \
  --body "Add docs/notes/spec-symphony-$(date +%Y%m%d-%H%M%S).md — new file only." \
  --sdd-framework auto \
  --change-type brownfield
```

## Postgres (local Guild compose)

```bash
PGPASSWORD=guild psql -h localhost -p 5433 -U guild -d guild_db
```

```sql
-- Agent ↔ runner binding (critical after runner replace)
SELECT agent_name, runner_id FROM agent_runner_bindings
WHERE agent_name LIKE 'spec-symphony%';

-- Runner heartbeat
SELECT runner_id, status, last_heartbeat FROM remote_runners
WHERE runner_id = 'spec-symphony-runner';

-- Latest workflow session
SELECT session_id, workflow_name, started_at
FROM session_index
WHERE workflow_name LIKE 'spec-driven-feature%'
ORDER BY started_at DESC LIMIT 5;
```

Session events hold orchestrator `note()` calls. Extract real note bodies with Python/jq — do not rely on naive `rg stage_summary` (spawn contract prose contains the same tokens).

## `{{work_root}}` wiring

- Guild substitutes `{{work_root}}` at spawn time with `WorkflowRunContext.ScratchPath()` (e.g. `$HOME/.wf-<run-id>`).
- Spawn templates must use:
  - `export WORK_ROOT='{{work_root}}'` (or double-quoted env) so child scripts inherit it
  - `\"{{work_root}}/repo\"` for **positional** path args (single quotes prevent `$HOME` expansion)

## Trim example (first stage only)

**Gate stages** (`*-blocked-gate`, `validate-loop-gate`) use `skip_to` / `loop_to` targets. Any stage referenced there **must** appear in `stages` — otherwise Temporal fails with `target "validate" not found in stage plans`. When trimming past implement, keep `validate` if gate stages remain; or drop gates and wire `implement-cdk` → `stage_depends_on = ["clone"]` directly.

```hcl
stages = [
  { stage_id = "intake-clone-bootstrap", description = "Parse webhook, clone repo", required = true },
]

stage_bindings = [
  {
    stage_id     = "intake-clone-bootstrap"
    agent_ref    = sg_agent.spec_symphony_orchestrator.name
    runbook_refs = [sg_runbook_sop.orchestration.name]
    skill_refs   = [local.sop_orchestration_name]
    spawn_contracts = local.spawn_contracts_intake_clone
    note         = local.intake_clone_bootstrap_stage_note
  },
]
```

## Re-bind orchestrator after runner churn

```bash
cd examples/scenarios/spec-symphony
tofu apply -replace='module.spec_symphony.sg_agent.spec_symphony_orchestrator'
```

## Script pack tarball pre-create (when `tofu apply` fails on filebase64)

```bash
cd modules/aios-agent-spec-symphony
NEWSHA=$(shasum -a 256 scripts/stage-runner.sh | awk '{print $1}')
rm -rf .generated/pack-staging
mkdir -p .generated/pack-staging
cp -R scripts/. .generated/pack-staging/
mkdir -p .generated/pack-staging/vendor
cp -R .generated/aidlc-rules .generated/pack-staging/vendor/aidlc-rules
tar -czf ".generated/specsym-script-pack-${NEWSHA}.tar.gz" -C .generated/pack-staging .
```

Then `tofu apply` from scenario root (may need two passes if provider reports inconsistent plan).

## Green run artifacts (spec-symphony, 2026-06)

Successful end-to-end validation:

- PR opened on unique branch `spec-symphony/<issue>-<run-token>`
- `note 'pr_url' saved`, `note 'update_tracker_result' saved`
- Issue comment with `notify_comment_id=`

Idempotent re-run with same body: implement may block or skip PR (`skipped_no_changes`) — expected.

## Adapting to other AIOS workflows

1. Identify the scenario under `examples/scenarios/<slug>/` or `examples/complete/`.
2. Find the agent module's `sg_workflow` resource and stage binding locals.
3. Find trigger script or webhook curl pattern in scenario `scripts/`.
4. List stage IDs from `stages` block — trim from the top of the dependency chain.
5. If the workflow uses **Ubuntu MCP** instead of remote runner, skip runner restart — use integration health checks instead.
6. If stages use **Cursor cloud agents** (no `execute_series`), bring-up order may differ; trim still applies but diagnosis uses Cursor task status not runner tasks.
