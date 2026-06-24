---
name: incremental-workflow-bring-up
description: >-
  Brings multi-stage StackGen Guild workflows online one stage at a time — trim
  sg_workflow stages/bindings, loop tofu apply → runner → trigger → diagnose,
  green each stage before adding the next. Use when debugging AIOS agent workflows,
  remote-runner script packs, spawn contracts, spec-symphony, or any long pipeline
  where full-run failures are hard to attribute.
---

# Incremental workflow bring-up

**Problem:** A multi-stage `sg_workflow` fails somewhere in a long chain. A full run mixes orchestrator LLM variance, runner tooling, spawn-contract quoting, and stage dependencies — failures are hard to localize.

**Technique:** Run a **lean workflow** with only the stages needed for the current hypothesis. **Green one stage**, then uncomment/add the next `stage` + `stage_binding`. Repeat until the full pipeline is restored.

Reference implementation: `modules/aios-agent-spec-symphony` (spec-driven-feature). Scenario loop: `examples/scenarios/<slug>/`.

---

## When to use

- First-time or broken bring-up of a remote-runner workflow
- After changing spawn contracts, stage notes, or script pack scripts
- User asks to "green one stage at a time", "keep the workflow lean", or "iterate until green"
- Full-run logs are noisy; you need a single failure surface

**Do not use** when the bug is clearly in foundation/policies (fix layer 0 first) or when only one stage exists.

---

## Phase 0 — Preconditions

Confirm before the loop:

| Check | How |
|-------|-----|
| Provider + module applied once | `tofu apply` from scenario root |
| Remote runner online | `remote_runners.status = online` (Guild DB or API) |
| Agent ↔ runner binding | `agent_runner_bindings` row for orchestrator agent |
| Trigger path works | Scenario `scripts/trigger-webhook.sh --from-tofu-output` |
| Server logs available | e.g. `/tmp/server.log` in local Guild dev |

If tools are "not available" (`*_execute_series` missing), **re-bind** before trimming stages:

```bash
tofu apply -replace='module.<name>.sg_agent.<orchestrator_resource>'
```

(`sg_remote_runner -replace` drops bindings; prefer `-replace` on the **agent** to restore `agent_runner_bindings`.)

---

## Phase 1 — Trim the workflow

In the agent module `main.tf`, edit the target `sg_workflow`:

1. **`stages`** — include only stages up to the one under test (keep `stage_depends_on` order in bindings).
2. **`stage_bindings`** — include matching bindings only; preserve `stage_depends_on` chain.

Comment at the top of the block what is green and what is "bringing up":

```hcl
# Incremental bring-up: greened intake-clone-bootstrap, repo-sdd-bootstrap.
# Bringing up: author-spec.
stages = [
  { stage_id = "intake-clone-bootstrap", ... },
  { stage_id = "repo-sdd-bootstrap", ... },
  { stage_id = "author-spec", ... },
]
```

**Rules:**

- Never delete stage definitions from `spawn_contracts.tf` / locals — only **omit** them from the workflow resource.
- Add **one stage per iteration** unless two are inseparable (document why).
- Restore the full `stages` + `stage_bindings` list only after all stages are green.

---

## Phase 2 — Iteration loop

Copy this checklist and update each pass:

```
Bring-up progress:
- [ ] tofu apply
- [ ] runner restart (only if pack/image/secrets changed)
- [ ] verify agent_runner_bindings
- [ ] LOGMARK server log
- [ ] trigger webhook
- [ ] diagnose outcome
- [ ] fix root cause (not symptoms)
- [ ] stage green → add next stage
```

### 2a. Apply

```bash
cd examples/scenarios/<slug>
tofu apply -auto-approve
```

If apply fails on **script pack tarball** (`filebase64` / missing archive): scripts changed but tarball path (keyed by `stage-runner.sh` sha) does not exist yet. Either pre-build the pack staging tarball under `modules/<agent>/.generated/` or **run `tofu apply` twice** (archive data source materializes on first pass).

### 2b. Runner restart (conditional)

Restart **only** when:

- `script_pack_version` bumped
- Runner Docker image tag changed
- Runner secrets (git token, script pack b64) changed

```bash
docker rm -f <runner-container-name>
./scripts/start-runner.sh --run   # scenario script
```

**Skip restart** for workflow-only changes (stage notes, spawn contract text in Guild, binding metadata) — avoids unnecessary binding churn.

After restart, verify binding:

```sql
SELECT agent_name, runner_id FROM agent_runner_bindings
WHERE agent_name LIKE '<orchestrator-prefix>%';
```

### 2c. Log mark + trigger

```bash
echo "LOGMARK=$(wc -l < /tmp/server.log)"
./scripts/trigger-webhook.sh --from-tofu-output \
  --repo <owner/repo> --issue <n> \
  --title "..." --body "..." \
  # ... scenario-specific flags
```

Record `run_id=` from trigger output.

### 2d. Wait and diagnose

**Wait budget (rough):** terminal_calling stages ~2–5 min; implement ~5–15 min; validate can poll runner tasks several minutes; full 6–7 stage run ~8–12 min.

**Evidence hierarchy** (use in order):

1. **Session notes** (best stage verdict) — latest `session_index` row for the workflow; grep `session_events.event_data` for:
   - `note '<key>' saved` (orchestrator persisted outcomes)
   - `stage_summary:<stage_id>=done|blocked`
   - Subagent stdout keys (`author_spec_status=`, `pr_url=`, `notify_comment_id=`)
   - Ignore tokens embedded in SOP/spawn-contract **text** (false positives like `clone_blocker=` in instructions)

2. **Server log since LOGMARK** — runner task polling, policy denials, surface guard

3. **Guild watch UI** or **execution debug bundle** — tool args/results (`subscribe-events.json` → `TOOL_CALL_START` / `TOOL_CALL_RESULT`)

4. **Postgres** — `remote_runner_tasks`, `agent_runner_bindings`, runner heartbeat

**Green criteria for a stage:** orchestrator wrote expected notes **and** subagent `execute_series` succeeded (or stage note documents an intentional skip with reason).

---

## Phase 3 — Common failure classes (remote-runner workflows)

| Symptom | Likely cause | Fix direction |
|---------|--------------|---------------|
| `execute_series` tools not in registry | Missing `agent_runner_bindings` | `-replace` orchestrator agent; avoid blind `sg_remote_runner -replace` |
| `missing WORK_ROOT` / `clone_blocker=missing_clone_params` | Env not exported to child shell | `export WORK_ROOT='{{work_root}}'` in spawn context; semicolon chain must export |
| `cd: $HOME/.wf-.../repo: No such file` | Literal `$HOME` in positional args | Use **double quotes** around `\"{{work_root}}/repo\"` in spawn templates |
| `cursor_blocker=agent_cli_not_installed` | `implement_engine=cursor_cli` without CLI on runner | Use `implement_engine=shell` for bring-up, or install CLI in runner image |
| Orchestrator plan-only, no `create_agent` | LLM variance / ambiguous goal | Re-trigger; tighten stage note + spawn goal |
| `stage_summary:create-pr=done` but empty `pr_url` | Committed on `main` or no diff | Feature branch in `commit-pr`; unique branch per run; unique trigger body for tests |
| Wrong path: notify instead of commit-pr | Stage note treats quality finding as blocker | Stage note: `NEEDS_REVISION` ≠ clone failure; default to commit-pr when clone OK |
| `push_error=failed` on repeat runs | Same branch name reused | Append run-id token to branch (`spec-symphony/<issue>-<token>`) |
| `REPO_FULL_NAME` unset in notify scripts | Agent left placeholder | Pass `WORK_ROOT`; script derives repo from `git remote` fallback |

Details and spec-symphony file map: [reference.md](reference.md).

---

## Phase 4 — Advance to next stage

When the current stage is green:

1. Add the next `{ stage_id = "...", ... }` to `stages`.
2. Add the matching `stage_bindings` block with correct `stage_depends_on`.
3. Comment which stages are now green.
4. Return to **Phase 2** (apply → trigger → diagnose).

After the **last** stage is green:

1. Restore full workflow description (remove DEBUG comments).
2. Run one **end-to-end** trigger with a **unique change request** (idempotent re-runs may produce no diff).
3. Optionally run `make verify-workflow-stage-bindings` if the module has binding tests.

---

## Trigger body discipline

For implement/create-pr stages, use a **unique artifact** per validation run (timestamped path in issue body). Otherwise implement may correctly no-op ("already exists") and create-pr returns `skipped_no_changes`.

---

## Script pack changes

When editing `modules/<agent>/scripts/*.sh`:

1. Bump `script_pack_version` in module `main.tf` locals.
2. Rebuild staging tarball if apply fails (see Phase 2a).
3. `tofu apply` → **restart runner** → trigger.

Spawn contexts embed pack paths like `${local.specsym_pack_dir}` — version bump forces runner re-extract.

---

## Anti-patterns

- Running all stages while debugging the first clone path
- Restarting the runner on every `tofu apply` (binding churn, wasted time)
- Diagnosing from grep of `server.log` alone (SOP text pollutes matches)
- Treating `module_quality_summary=NEEDS_REVISION` as a workflow stop for PR stages
- Reusing the same issue body across runs when testing implement/PR paths

---

## Additional resources

- Spec-symphony file map, SQL snippets, spawn-context patterns: [reference.md](reference.md)
- Execution debug bundle interpretation: use `guild-execution-debug-bundle` skill (stackgen-guild / stackgen-sre-app)
- Stuck sessions / Postgres: use `troubleshoot-session-executions` skill
