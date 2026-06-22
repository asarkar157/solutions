# Spec-Driven Orchestration

Guild **Stage 5 factory** (`aios-agent-spec-symphony`) bridges manual Stage 4 SDD tools (Spec Kit, OpenSpec, Kiro) to autonomous pipelines.

## Maturity model

| Stage | Name | Tools |
|-------|------|-------|
| 3 | Interactive steering | Cursor, Kiro, Claude Code |
| 4 | Manual orchestration | Spec Kit CLI, OpenSpec CLI — human advances phases |
| 5 | Autonomous factory | `aios-agent-spec-symphony` — webhook → workflow → remote runner |

Stage 4 and Stage 5 coexist. Teams adopt the **SDD Kit starter** (constitution, change types, CI spec-linkage) at Stage 4, then opt into the Guild factory when ready.

## Architecture

```
GitHub / Linear webhook → sg_webhook → spec-driven-feature workflow
  → spec-symphony-orchestrator (remote runner execute_series)
  → clone → spec-bootstrap → author-spec → implement → validate → evidence gate → PR → tracker
```

## Linear two-phase (product spec → blessed implement)

Two workflows replace a single monolithic Linear path for PM/engineering handoff:

| Workflow | Trigger | Output |
|----------|---------|--------|
| **`linear-product-spec`** | Linear issue with label `needs-spec` | Golden-template spec + engineering subgoals posted as **Linear comment** (no runner) |
| **`linear-spec-implement`** | Same issue labeled `spec-blessed` | Fetch comment → clone repo → materialize `specs/<ID>/` → **Cursor CLI** implement → validate → PR → Linear status comment |

### Operator runbook

1. Create Linear product ticket with product requirements; add label **`needs-spec`**.
2. Configure Linear webhook → `linear_product_spec_webhook_trigger_url` (from scenario/module outputs).
3. Review the bot comment (`<!-- spec-symphony-spec-v1 -->` marker). Add label **`spec-blessed`** when approved.
4. Ensure issue body includes `repo: owner/name` for the implement phase.
5. Configure second Linear webhook → `linear_spec_implement_webhook_trigger_url`; start remote runner with `CURSOR_API_KEY` when `linear_implement_engine=cursor_cli`.
6. Implement workflow opens a GitHub PR; merge-time CI (`ci-spec-linkage.sh`) still applies.

Legacy **`spec-driven-feature`** + `linear_receiver` webhook remains available via `enable_legacy_linear_factory_webhook = true`.

## Framework routing

- **spec-kit**: greenfield — `.specify/`, `specs/NNN-feature/`
- **openspec**: brownfield — `openspec/changes/<id>/`, `openspec archive`
- **auto**: detect from repo layout or `change_type`

## References

- [GitHub Spec Kit](https://github.com/github/spec-kit)
- [OpenSpec](https://openspec.dev/)
- [OpenAI Symphony SPEC](https://github.com/openai/symphony/blob/main/SPEC.md)
- Piskala (2026) — Spec-Driven Development spectrum ([arXiv:2602.00180](https://arxiv.org/abs/2602.00180))

## Module

[`modules/aios-agent-spec-symphony`](../modules/aios-agent-spec-symphony/README.md)

Example scenario: [`examples/scenarios/spec-symphony`](../examples/scenarios/spec-symphony/)

## Governance and enforcement

Central platform teams and Guild split enforcement: **GitHub/org controls merge behavior**; **Guild controls factory behavior** for work that flows through `spec-driven-feature`.

### Tier A — Merge-time (all service repos)

| Lever | Owner | Effect |
|-------|-------|--------|
| Org ruleset requiring `SDD Compliance and Specification Linkage` | Central | Blocks merge when code changes without matching spec file diff |
| Branch protection (no direct push to `main`) | Central | Forces PR path where CI runs |
| CODEOWNERS on `specs/**`, `openspec/**`, `.specify/**` | Central | Architecture review on spec changes |
| SDD Kit starter adoption | Central → repos | Seeds `constitution.md`, CI workflow, PR template |

Repo CI (`ci-spec-linkage.sh`) checks **presence** of spec file changes, not semantic quality or constitution compliance.

### Tier B — Factory-time (ticket-driven work)

| Lever | Where | Effect |
|-------|-------|--------|
| Webhook + optional label gate (`spec-symphony`) | Deploy config | Reduces noise; does not stop manual PRs |
| `author-spec` stage | Workflow | Thin tickets → `spec.md` / `plan.md` / `tasks.md` (or OpenSpec change folder) |
| `validate-and-test` → `ci-spec-linkage.sh` | Remote runner | Hard fail → `module_quality_summary=NEEDS_REVISION` |
| Workflow gates (`author-blocked-gate`, `implement-blocked-gate`, `validate-loop-gate`) | Guild | Skip/loop/abort paths |
| `spec-evidence-gate` (`evidence_gate`) | Before `create-pr` | LLM verifies spec linkage evidence items |

### Tier C — Guild hard gates (module enhancements)

| Enhancement | Effect |
|-------------|--------|
| `spec-evidence-gate` | Blocks PR stage until evidence checklist items include spec linkage |
| `spec-traceability` Rego policy | HITL on ad-hoc `gh pr create` / commit+push without `specs/` or `openspec/changes/` |
| `implement_engine=cursor_cli` | Headless Cursor Agent on runner (`agent -p --trust --yolo`) for author/implement |

### What neither layer solves alone

- Developers committing directly to `main` without branch protection
- Repos that never adopt the SDD Kit starter
- Teams that skip the factory entirely (human bypass)
- Spec **quality** (empty specs, wrong AC) — pair ticket templates + future spec lint

### Decision matrix

| Goal | Central team | Guild |
|------|--------------|-------|
| No code without spec file diff | Required GitHub check | `validate.sh` + ci-spec-linkage |
| Thin tickets get real specs | Ticket template (AC, repo link) | `author-spec` stage |
| Block agent PR without proof-of-spec | — | `spec-evidence-gate` + Rego |
| Constitution rules followed | CODEOWNERS + review | SOP + prompts (soft) |

Set `require_tracker_label = true` in module Terraform and configure your webhook receiver to only trigger labeled issues when central teams want factory-only intake.

