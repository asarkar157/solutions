# Scenario: `monorepo-services-split`

## Pitch (read this on the call)

> "Hand me your monorepo URL. Aiden clones it, scans Go / TypeScript / Java boundaries, applies DDD and strangler-fig thinking, and opens a PR back to your repo with a bounded-context map, coupling matrix, migration phases, and a proposed service catalog — then optionally scaffolds `services/<name>/` for extraction."

## What this scenario wires

- `aios-foundation` — LLM secrets + models
- `aios-policies` — minimal set
- `aios-integration-github` + `aios-integration-ubuntu` — clone, scan, PR
- `aios-agent-monorepo-services-splitter` — architect + analyst + optional Cursor executor

## Run

```bash
make demo SCENARIO=monorepo-services-split
```

## Talk track (5 bullets, ~5 minutes)

1. **Open Guild and find `monorepo-split-architect`.** Two workflows — analysis (guidance PR) and extract (scaffold + optional Cursor).
2. **Run `monorepo-services-split-analysis`** with a public monorepo URL (e.g. a known Go + TS OSS repo from tfvars).
3. **Show the boundary scan stage.** Ubuntu runner clones and emits `boundary_scan.json` — facts before LLM judgment.
4. **Show analyst stages.** Bounded contexts, coupling heat, service catalog with migration phases — not ad-hoc chat.
5. **Show the guidance PR** on the same repo under `docs/architecture/` — PR-only, never push to default branch.

## Reset

```bash
make demo-reset SCENARIO=monorepo-services-split
```
