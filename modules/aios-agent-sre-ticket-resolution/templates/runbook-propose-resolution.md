Propose a bounded AWS remediation plan for a ServiceNow ticket based on investigation evidence.

## Prerequisites

- `investigation_report` JSON from the investigate stage.
- `enriched_ticket` JSON for ticket scope and CI linkage.

## Steps

1. Select remediation category from investigation output (`restart`, `scale`, `rollback`, `runbook`, `escalate`).
2. List concrete AWS actions with resource ARNs or names — smallest blast radius first.
3. Document pre-checks, expected duration, rollback steps, and post-verification queries (Grafana + CloudWatch).
4. Flag when human approval is required (P1/Critical, prod-write, or tier-0 resources).
5. Emit `resolution_plan` JSON — **no mutating AWS calls** in this stage.

## Guardrails

- Do not modify ServiceNow state beyond optional planning work notes when explicitly requested.
- Escalate instead of planning destructive actions when evidence is weak.
