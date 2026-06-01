Recommend remediation actions — **documentation only** for production.

Environment: **${private_saas_environment_label}**

## Steps

1. Review RCA and matched runbooks.
2. For **production**: output step-by-step recommendations, change-ticket text, and rollback notes — **no automated applies**.
3. For non-production: you may suggest concrete commands but still require HITL before execution.
4. Emit `recommended_actions` JSON with risk tier and approval requirements.

## Guardrails

- Never execute mutating GCP/Grafana/FireHydrant calls in this stage.
- P1/SEV1 requires explicit human approval for any automation.
