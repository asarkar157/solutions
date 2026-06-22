# Incident Triage PoC — honest limits

This document sets expectations for evaluators and SEs. It complements the PoC runbook in [`examples/scenarios/incident-triage/README.md`](../examples/scenarios/incident-triage/README.md).

## What the PoC proves

- **Reproducible scorecard** on the customer's past incidents (golden dataset + human rubric)
- **Visible tuning** — manifest skills, Terraform modules, curated memory import
- **Before/after lift** after `bootstrap-memory.sh` seeds `shared:incidents`

## What the PoC does not claim

- Feature parity with Resolve.ai (60+ connectors, remediation PR automation) or PlayerZero (code simulation)
- Sub-2-minute p50 on full `investigate-alert` without measurement first
- Automatic episodic memory approval or promotion UI

## Offline vs live replay

| Mode | Data available | Expected automated RCA quality | Use in competitive demo |
| ---- | -------------- | ------------------------------ | ----------------------- |
| `offline` | Prompt + labels only; no live metrics | Lower — agent lacks PromQL/log evidence | Baseline honesty; taxonomy |
| `live_replay` | Alert re-fired in customer Grafana | Higher — full investigate path | Head-to-head vs Resolve 5-min claim |

**Mitigation:** Split customer dataset ~70% offline / ~30% live_replay. Lead procurement with live_replay scores; document offline as conservative floor.

## OOTB category expectations (pre-eval)

Update after eval v1 in [`incident-triage-poc-taxonomy.md`](./incident-triage-poc-taxonomy.md).

| Category | OOTB expectation | Why |
| -------- | ---------------- | --- |
| `capacity` | pass | Grafana + k8s enrichment; eviction QA covered |
| `deploy` | pass | Change-correlation spawn when GitHub wired |
| `config` | pass | Alert rule + target probe path |
| `dependency` | weak | Symptom vs cause needs cross-service signals |
| `network` | weak | Often needs AWS/cloud integration not in default scenario |
| `data` | weak/fail | DB internals rarely in Grafana-only stack |
| `unknown` | fail | Requires SE labeling + tuning |

## Memory layers (honest model)

### Episodic (Genie `memory_store`)

- Written during agent runs; **not auto-injected** into every turn
- Agent must call `memory_search`; classify workflows forbid memory tools
- **No approval UI** — Memory Explorer is browse/delete only

### Shared incident memory (`shared:incidents`)

- Used by `prior-incident-search` and `persist-incident-memory` skills
- **Not auto-provisioned** — org must create namespace + RBAC
- PoC bootstrap imports **curated** golden RCAs (human-approved provenance)

### Wisdom (governed)

| Type | Delivery | Honored when |
| ---- | -------- | ------------ |
| Approved runbook | Pushed into stage | Always when bound |
| Bundled skill | Pushed via `skill_refs` | Always |
| Knowledge doc | Pulled via search | If agent searches + match quality |
| KG node | Pulled via `graph_query` | After discovery ingest |
| `shared:incidents` | Pulled via memory search | Score ≥ 0.3 match; reuse at ≥ 0.7 |

**PoC story:** competitors claim opaque learning; we show Memory Explorer + curated import + scorecard lift.

## Memory → wisdom ladder (manual today)

```text
Agent episodic write → SE reviews in Memory Explorer → delete bad / keep good
Curated bootstrap import → shared:incidents → prior-incident-search reuse
Postmortem PDF → Knowledge doc (ready) → knowledge_search
Repeated pattern → draft runbook → approve → pushed into investigate stage
Discovery run → graph_store → graph_query enrichment
```

There is **no one-click promote memory → runbook** in v1. SE promotes content manually.

## Bootstrap provenance fields

`bootstrap-memory.sh` stamps metadata in stored text:

- `source` — e.g. `curated_import`, postmortem link
- `approved_by` — reviewer email from JSONL row
- `incident_id` — stable dataset id
- `type=curated_import`

Evaluators can filter Memory Explorer by these fields during the demo.

## Scorecard columns that expose memory behavior

| Column | Meaning |
| ------ | ------- |
| `prior_incidents_count` | Tool/search activity hint from trace (not match quality) |
| `memory_persist_skipped` | Manual note when persist skill skipped (low confidence) |
| Human `human_correctness` vs `golden_root_cause` | Authoritative accuracy |

## When to defer product work

- **`investigate-alert-poc` fast workflow** — only if measured p50 > 120s and accuracy acceptable
- **LLM RCA judge** — after human rubric stable and n > 20
- **SRE app eval API** — script + CSV sufficient for PoC period
