# Terraform Bot — Cross-Verification Action Plan

Use this checklist to confirm the consolidation changes (priority top 5 + sections D–G) landed correctly in `aios-agent-terraform-bot` and behave as expected at runtime.

**Module version marker:** `script_pack_version=20260531.22` (in `main.tf` locals and embedded script stdout).

---

## 1. Static verification (local, ~2 min)

Run from repo root:

```bash
cd modules/aios-agent-terraform-bot

# Structure + policy checks (gates, budgets, spawn rules, embeds)
bash tests/workflow_structure_test.sh

# Stage-runner unit checks (if present)
bash tests/stage_runner_logic_test.sh 2>/dev/null || true

# Terraform syntax
tofu fmt -check main.tf spawn_contracts.tf variables.tf
```

| # | Check | Pass criteria | File / command |
|---|--------|---------------|----------------|
| 1.1 | Structure tests green | Exit 0, prints `OK: workflow structure checks passed` | `tests/workflow_structure_test.sh` |
| 1.2 | Script pack version | `20260531.21` | `main.tf` → `local.script_pack_version` |
| 1.3 | Budget defaults | `script_runner=8`, `validate_runner=12`, `hcl_author=20`, `github_notify=5` | `main.tf` → `subagent_budget_defaults` |
| 1.4 | `defer_pr_until_quality_pass` default | `default = true` | `variables.tf` |
| 1.5 | No `workflow_script_pack` in stage `skill_refs` | Absent from binding `skill_refs` blocks | `main.tf` stage_bindings |
| 1.6 | HalGuard metadata | `halguard_skip_subagent_task_types = "terminal_calling"` | `sg_workflow.terraform_module_update.metadata` |

---

## 2. File-by-file change matrix

Cross-check each recommendation against the module artifact.

### Priority #1 — Discovery greenfield: scaffold + validate in one embed

| # | Artifact | What to verify |
|---|----------|----------------|
| 2.1 | `templates/discovery-scaffold-execute-series-embedded.sh.tftpl` | After scaffold, calls `stage-runner validate`; emits `discovery_greenfield_validated=true`, `validate_markers_file=`, quality markers |
| 2.2 | `templates/discovery-scaffold-execute-series-embedded.sh.tftpl` | Validates `variables.tf.json` / `outputs.tf.json` with `jq empty`; renames sibling → module dir |
| 2.3 | `main.tf` | Stage `validate-greenfield-skip-gate` exists; `match = "discovery_greenfield_validated=true"`; `skip_to = "validate-infra-gate"` |
| 2.4 | `spawn_contracts.tf` | `implement-module-discovery-scaffold` uses `script_runner_max_llm_calls` (not hcl_author); goal forbids `validate-and-test-runner` |

### Priority #2 — Gate regex fixes

| # | Gate | Pass criteria | Location |
|---|------|---------------|----------|
| 2.5 | `validate-infra-gate` | Match includes `module_quality_summary:\s*BLOCKED` **without** `(?m)^\s*…$` line anchors | `main.tf` |
| 2.6 | `validate-draft-pr-gate` | Match is **only** `pr_url=https://github\.com/[^\s]+` (no bare `pr_draft=true`) | `main.tf` |
| 2.7 | `validate-loop-gate` | `exit_match` includes both `PASS` and `BLOCKED` | `main.tf` |

### Priority #3 — Cap terminal_calling + ban load_skill

| # | Check | Pass criteria |
|---|--------|---------------|
| 2.8 | Spawn contracts | No `load_skill` in `tool_names` for clone / discovery / validate / create-pr runners |
| 2.9 | Spawn goals | Each terminal runner goal starts with “FIRST TOOL CALL MUST be execute_series (never load_skill)” |
| 2.10 | Stage notes | `FORBIDDEN: load_skill` when `---BEGIN *_EXECUTE_SERIES---` in spawn context |

### Priority #4 — Stage-boundary spawn rules

| Stage | Must NOT spawn |
|-------|----------------|
| 2.11 `check-info-and-clone` | `implement-module-*`, `validate-and-test-runner`, `create-pr-*` |
| 2.12 `implement-module` | `validate-and-test-runner`, `create-pr-*` |
| 2.13 `validate-and-test` | `implement-module-*`, `create-pr-*`, `create-pr-evidence-submit` |
| 2.14 `create-pr` | `validate-and-test-runner`, `implement-module-*`; use architect `submit_evidence` not `create-pr-evidence-submit` |

Reference table: `templates/terraform-bot-orchestration-extensions.md.tftpl` §3e.

### Priority #5 — HalGuard scope hint

| # | Check | Pass criteria |
|---|--------|---------------|
| 2.15 | Workflow metadata | `terminal_calling_halguard_mode`, `halguard_skip_subagent_task_types` set |
| 2.16 | Orchestration §3i | Documents paste-only runners, no `load_skill` on embedded stages |
| 2.17 | **Guild-side** (out of module) | Confirm Guild honors metadata or HalGuard cost remains high — see §6 |

### Section D — Spawn / budget extras

| # | Check | Pass criteria |
|---|--------|---------------|
| 2.18 | `create-pr-notify` | Defined in `spawn_contracts.tf`; `max_llm_calls=5`; GitHub tools only |
| 2.19 | `create-pr` stage note | Blocked paths prefer `create-pr-notify` over `create-pr-runner` |

### Section F — Script changes

| # | Check | Pass criteria |
|---|--------|---------------|
| 2.20 | `scripts/stage-runner.sh` | tfsec and checkov run in parallel (`tfsec_pid` / `checkov_pid` + `wait`) |
| 2.21 | `templates/validate-execute-series-embedded.sh.tftpl` | Emits `validate_markers_file=$WORK_ROOT/.work/validate.out` |
| 2.22 | `defer_pr_until_quality_pass=true` | Validate embed skips draft PR on NEEDS_REVISION unless module var overridden |

---

## 3. Deploy module to local Guild

Prerequisite: Guild dev stack up (`make dev` in stackgen-guild), Postgres on `:5433`.

```bash
cd stackgen-guild/terraform/guild
tofu plan -var-file=tfvars/local.tfvars
tofu apply -var-file=tfvars/local.tfvars
```

| # | Check | Pass criteria |
|---|--------|---------------|
| 3.1 | Plan shows workflow/agent updates | `sg_workflow.terraform_module_update`, spawn_contracts, stage_bindings diff |
| 3.2 | Apply succeeds | No provider errors; workflow `terraform-module-update` updated |
| 3.3 | Guild UI / API | Workflow stages include `validate-greenfield-skip-gate` between `implement-module` and `validate-and-test` |

---

## 4. Runtime verification — single greenfield run

Trigger one discovery greenfield issue:

```bash
cd modules/aios-agent-terraform-bot/scripts

GUILD_URL=http://localhost:8081 \
PG_URL='postgres://guild:guild@localhost:5433/guild_db?sslmode=disable' \
./trigger-webhook.sh \
  --from-tofu-output \
  --create-github-issue \
  --title "Add aws_scheduler_schedule discovery module" \
  --body "EventBridge Scheduler schedule resource for discovery-modules layout test"
```

Note `run_id` / `trace_id` from output, then monitor:

```bash
./monitor-workflow-run.sh --trace-id <TRACE_ID> --timeout 3600
```

### 4a. Stage flow (execution trace)

| # | Expected behavior | How to verify |
|---|-------------------|---------------|
| 4.1 | Single clone subagent | Trace shows one `check-info-and-clone-clone`; no duplicate clone planning |
| 4.2 | One discovery embed | `implement-module-discovery-scaffold` only; **no** `validate-and-test-runner` in implement stage |
| 4.3 | Skip duplicate validate | Output contains `discovery_greenfield_validated=true`; stage `validate-and-test` **skipped** (gate fires) |
| 4.4 | No spurious GO_BACK | No loop `implement@1` + `validate@1` for init errors caught at scaffold time |
| 4.5 | Gate path | Flow reaches `validate-infra-gate` → `validate-draft-pr-gate` → `validate-loop-gate` → `create-pr` |

### 4b. Subagent budgets (trace / logs)

| Subagent | Max LLM calls (module default) | Red flag |
|----------|----------------------------------|----------|
| `check-info-and-clone-clone` | 8 | >8 or `load_skill` invocations |
| `implement-module-discovery-scaffold` | 8 | >8; separate validate runner spawned |
| `validate-and-test-runner` | 12 (only if skip gate did **not** fire) | `load_skill` loops |
| `create-pr-notify` | 5 (blocked path only) | Ubuntu tools used for notify-only path |

### 4c. stdout markers (subagent output)

| Marker | Required when |
|--------|---------------|
| `fmt_exit=` | Any real validate (discovery embed or validate runner) |
| `binary=OpenTofu` or `binary=Terraform` | Same |
| `module_quality_summary=PASS\|NEEDS_REVISION\|BLOCKED` | After validate |
| `discovery_greenfield_validated=true` | Discovery greenfield path |
| `validate_markers_file=` | Validate embed paths |
| `pr_url=https://github.com/...` | Only when PR actually opened (draft gate requires this) |

### 4d. Cost / duration sanity (vs pre-change baseline ~891s / $1.94)

| Metric | Target direction | Notes |
|--------|------------------|-------|
| Wall time | ↓ ~400s on greenfield | Fewer implement+validate round-trips |
| LLM calls | ↓; no 100k+ token bursts | No `load_skill` on embedded stages |
| Shell time | Still low (~10–20s) | Most work is paste-and-run |
| HalGuard calls | ↓ if Guild honors metadata | See §6 if still ~35% of cost |

---

## 5. Scenario matrix (spot-check)

Run at least one row end-to-end; tick when observed.

| Scenario | Trigger | Expected outcome |
|----------|---------|------------------|
| 5.1 Greenfield PASS | New discovery module issue | PR opened (or deferred until PASS if quality fails); skip gate fired |
| 5.2 Greenfield NEEDS_REVISION | Issue with bad sibling mirror / invalid HCL | `module_quality_summary=NEEDS_REVISION`; **no** `pr_url` (defer default); loop or blocked comment |
| 5.3 Infra BLOCKED | Ubuntu sidecar down / fake validate stdout | `module_quality_summary: BLOCKED` matches infra gate; `create-pr-notify` only; **no** rework loop |
| 5.4 Clone blocked | Private repo without PAT | `check-info-blocked-gate` → `create-pr`; `create-pr-notify`; no implement/validate |
| 5.5 Draft PR path (opt-in) | Set `defer_pr_until_quality_pass = false` in module | NEEDS_REVISION opens draft PR with real `pr_url`; draft gate skips rework loop |

---

## 6. E2E acceptance — 4 consecutive PRs

```bash
cd modules/aios-agent-terraform-bot/scripts
GUILD_URL=http://localhost:8081 \
PG_URL='postgres://guild:guild@localhost:5433/guild_db?sslmode=disable' \
./run-consecutive-pr-e2e.sh 4
```

| # | Pass criteria |
|---|---------------|
| 6.1 | Script exits 0 after 4 successful runs |
| 6.2 | Each run produces a GitHub PR URL (or documented blocker with notify comment) |
| 6.3 | No run exceeds budget / hits `max LLM calls` on script runners |

---

## 7. Known blind spots (not verified by module alone)

Track separately; module changes do not fully resolve these.

| Item | Symptom | Owner / next step |
|------|---------|-------------------|
| Stdout truncation | `validate@1` BLOCKED despite live sidecar; missing `fmt_exit=` in tool result | Guild `execute_series` result size limits |
| create-pr 190s stall | Agent stage blocks after subagents complete | Guild stagerunner / stage completion signaling |
| HalGuard 35% cost | 24 Gemini flash calls vs 8 shell calls | Guild `halguard` config + workflow metadata consumption |
| Sibling mirror quality | Invalid JSON schema after cp sibling | Improve discovery template / layout SOP iter0 fixes |

---

## 8. Not in scope (deferred architectural items)

These were in the consolidation doc but **not** implemented — do not expect them when cross-verifying:

- Merge `bootstrap` + `check-info-and-clone` → single `intake-and-clone` stage
- Full `scaffold-and-validate` stage (replaced by inline embed + skip gate)
- Split `create-pr` into separate workflow stages (`notify` vs `register-and-pr`)
- Parallel `create-pr-register` ∥ issue comment
- Architect 0-LLM stages (planner still runs LLM per stage)
- Trim orchestration SOP injection size (127k → section refs)

---

## 9. Sign-off

| Area | Verifier | Date | Pass / Fail | Notes |
|------|----------|------|-------------|-------|
| Static tests (§1–2) | | | ☐ | |
| Local apply (§3) | | | ☐ | |
| Single greenfield run (§4) | | | ☐ | |
| Scenario spot-checks (§5) | | | ☐ | |
| 4× consecutive E2E (§6) | | | ☐ | |

**Reference trace (pre-change baseline):** session `114bfad0-1224-441f-a05d-33fe9b9320aa`, execution `24bdd080a6f54216a42af583dff842e3` (~891s, $1.94, wrong-stage spawns, gate misses).
