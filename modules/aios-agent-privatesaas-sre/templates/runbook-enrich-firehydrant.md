Enrich the incident from FireHydrant timeline, responders, and linked alerts.

## Steps

1. Load incident by id from normalized envelope.
2. Document timeline milestones (declared, mitigated, resolved).
3. List responders, roles, and escalation paths.
4. Attach linked monitor/alert references from FireHydrant.
5. Emit `firehydrant_enrichment` JSON.

## Guardrails

- Read-only; do not change incident status without HITL.
