Search Guild shared memory for prior incidents similar to the inbound Grafana alert.

## Prerequisites

- `normalized_alert` JSON from normalize-alert stage.

## Steps

1. Build a semantic query from `alert_name`, `service`, `namespace`, `cluster`, and `severity`.
2. Call **`memory_search`** with namespace `shared:incidents`, top_k 5, score_threshold 0.3.
3. Optionally call **`graph_query`** for the affected `service` node — retrieve prior root causes and linked investigation_ids.
4. If a match score ≥ 0.7, extract `reuse_hypothesis` and `confidence_boost` from the best match.
5. Emit `prior_incidents` JSON:

```json
{
  "query": "...",
  "matches": [{"investigation_id": "...", "summary": "...", "score": 0.82, "root_cause": "..."}],
  "reuse_hypothesis": "...",
  "confidence_boost": "high|medium|none",
  "skip_branches": ["hypothesis-deploy-regression"]
}
```

## Guardrails

- Read-only — do not write memory in this stage.
- Empty memory on first deploy is expected; continue with full investigation when no matches.
- Redact PII from match summaries.
