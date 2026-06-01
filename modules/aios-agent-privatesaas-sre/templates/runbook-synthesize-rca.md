Synthesize structured RCA from Grafana, GCP, FireHydrant, internal tooling, and matched runbooks.

Environment: **${private_saas_environment_label}**

## Steps

1. Merge prior stage JSON into a single timeline.
2. State likely root cause with confidence and supporting evidence links.
3. Document blast radius and customer impact for PrivateSaaS tenants.
4. Reference matched runbook steps that apply.
5. Emit `rca` markdown JSON: summary, timeline, root_cause, evidence_links, runbook_refs.

## Guardrails

- Factual evidence only; label hypotheses clearly.
