Synthesize a structured RCA document from cross-signal investigation evidence for Grafana alert incidents.

## Prerequisites

- `investigation_report` JSON from cross-signal-investigate stage.
- `normalized_alert`, `prior_incidents`, and `alert_classification` JSON.

## Steps

1. Review ranked hypotheses and evidence from the investigation report; honor `prior_incidents.reuse_hypothesis` when confidence_boost is high.
2. Build a chronological **timeline** of alert fire, metric shifts, deploy events, config changes, and relevant commits.
3. State a clear **root_cause** with confidence level and supporting cross-signal evidence.
4. Document **blast_radius** (single service vs shared infra) and user-visible symptoms.
5. Collect **evidence_links**: Grafana dashboard URLs, GitHub commit SHAs, AWS event ids, k8s event excerpts.
6. Write an executive **summary** (2–4 sentences) suitable for Slack.
7. Emit structured RCA JSON:

```json
{
  "investigation_id": "...",
  "summary": "...",
  "alert_role": "symptom|cause|unknown",
  "timeline": [{"ts": "...", "event": "..."}],
  "hypotheses": [{"name": "...", "confidence": "high|medium|low", "evidence": ["..."]}],
  "root_cause": "...",
  "confidence": "high|medium|low",
  "evidence_links": [{"source": "grafana|github|aws|k8s", "url": "...", "label": "..."}],
  "recommended_next_steps": ["..."]
}
```

## Guardrails

- Do not speculate beyond evidence — mark low-confidence hypotheses explicitly.
- Redact PII from RCA JSON.
