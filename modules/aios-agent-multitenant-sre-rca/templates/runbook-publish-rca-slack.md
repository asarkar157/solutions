Format and publish a synthesized RCA to Slack for multi-tenant SaaS incident response.

## Prerequisites

- Structured RCA JSON from synthesize-rca stage.
- Slack channel configured: `${slack_rca_channel}` (fallback to collaboration hint `${slack_collaboration_channel_hint}`).

## Steps

1. Validate RCA JSON has required fields: summary, timeline, root_cause, evidence_links, tenant_impact, investigation_id.
2. Format a Slack message:
   - Header with severity and tenant_id
   - Root cause headline
   - Compact timeline (3–5 bullets)
   - Top evidence links (Datadog, GCP, AWS, GitHub)
   - Tenant impact summary
   - Footer with investigation_id for thread follow-up
3. Post to `${slack_rca_channel}` and capture `slack_thread_ts`.
4. Emit `publish_result` JSON with `channel`, `thread_ts`, `investigation_id`, and `permalink` when available.

## Guardrails

- Do not re-investigate — publish the synthesized RCA unless required fields are missing.
- Redact PII from Slack messages.
- Include investigation_id so users can continue via the collaboration workflow webhook.
