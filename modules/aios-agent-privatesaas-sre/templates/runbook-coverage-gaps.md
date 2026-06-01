Identify runbook coverage gaps for PrivateSaaS services and failure modes.

## Steps

1. Compare `runbook_inventory` against top N recurring incident types (from FireHydrant or operator input).
2. Flag services with no matched runbook above confidence threshold.
3. Flag missing environments (staging vs prod parity).
4. Emit `coverage_gaps` JSON with prioritized backlog suggestions.

## Guardrails

- Read-only audit; no runbook edits.
