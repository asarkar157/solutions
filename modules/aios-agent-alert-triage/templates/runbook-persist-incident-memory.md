Persist RCA outcomes to Guild shared memory for future alert storms.

## Prerequisites

- Structured RCA JSON from synthesize-rca stage with `confidence` ≥ medium.
- `normalized_alert` with `investigation_id`, `alert_name`, `service`, `namespace`.

## Steps

1. If `confidence` is `low`, skip write-back and emit `memory_persist: { "skipped": true, "reason": "low confidence" }`.
2. Build a redacted memory document: alert fingerprint, root_cause, summary, investigation_id, key evidence links.
3. **`memory_store`** — Write to namespace `shared:incidents` keyed by alert_name + service + namespace fingerprint.
4. **`graph_store`** — Entities: service → caused_by → root_cause; link investigation_id for thread follow-up.
5. Emit `memory_persist` JSON with stored keys and graph entity ids.

## Guardrails

- No PII or credentials in stored memories.
- Skip write when policy evaluation blocks memory tools.
- First deploy may have empty prior memory — this stage seeds future `search-prior-incidents` hits.
