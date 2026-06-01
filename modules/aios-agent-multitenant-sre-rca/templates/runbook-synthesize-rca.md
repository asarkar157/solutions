Synthesize a structured RCA document from cross-signal investigation evidence for multi-tenant SaaS incidents.

## Prerequisites

- `investigation_report` JSON from cross-signal-investigate stage.
- `normalized_alert` JSON with tenant scope and monitor linkage.

## Steps

1. Review ranked hypotheses and evidence from the investigation report.
2. Build a chronological **timeline** of alert fire, metric shifts, deploy events, config changes, and relevant commits.
3. State a clear **root_cause** with confidence level and supporting cross-signal evidence.
4. Document **tenant_impact**: affected tenant_id, blast radius (single-tenant vs shared infra), and user-visible symptoms.
5. Collect **evidence_links**: Datadog monitor/dashboard URLs, GCP log query links, CloudTrail event ids, GitHub commit SHAs.
6. Write an executive **summary** (2–4 sentences) suitable for Slack.
7. Emit structured RCA JSON:

```json
{
  "investigation_id": "...",
  "tenant_id": "...",
  "summary": "...",
  "timeline": [{"ts": "...", "event": "..."}],
  "root_cause": "...",
  "confidence": "high|medium|low",
  "evidence_links": [{"source": "datadog|gcp|aws|github", "url": "...", "label": "..."}],
  "tenant_impact": "...",
  "recommended_next_steps": ["..."]
}
```

## Guardrails

- Do not speculate beyond evidence — mark low-confidence hypotheses explicitly.
- Keep tenant scope explicit in every section.
- Redact PII from RCA JSON.
