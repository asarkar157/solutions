Classify whether the firing alert is a downstream symptom or an upstream cause indicator.

## Prerequisites

- `normalized_alert` and optional `prior_incidents` from prior stages.

## Steps

1. Inspect alert name, metric type, and labels against symptom vs cause heuristics:
   - **Symptom**: frontend latency, HTTP 5xx rate, availability SLO burn, user-facing error budget.
   - **Cause**: connection pool exhaustion, CPU/memory saturation, disk I/O, container restarts, DB pool limits.
2. Set `alert_role` to `symptom`, `cause`, or `unknown`.
3. When `alert_role=symptom`, list likely upstream cause candidates from co-firing related alerts in `normalized_alert.labels` and `prior_incidents`.
4. When `prior_incidents.confidence_boost` is high, note which hypothesis branches may be skipped downstream.
5. Emit `alert_classification` JSON with `alert_role`, `likely_upstream`, and `storm_context` (single alert vs correlated group).

## Guardrails

- Classification is advisory — downstream stages must still gather evidence.
- Do not page or escalate based on classification alone.
