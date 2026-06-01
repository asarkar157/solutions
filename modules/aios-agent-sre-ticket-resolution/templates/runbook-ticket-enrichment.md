Enrich an inbound ServiceNow incident or problem ticket into a stable envelope for SRE investigation.

## Steps

1. Parse ticket JSON: `sys_id`, number, priority, assignment group, category, short description, configuration item, and affected service.
2. Map ServiceNow priority to internal severity (P1–P5 / Critical–Low).
3. Build an `enriched_ticket` object with: `ticket_sys_id`, `number`, `severity`, `assignment_group`, `category`, `short_description`, `ci`, `service`, `opened_at`, `servicenow_url`.
4. Add structured work notes summarizing ingest metadata and planned investigation scope.
5. Post a concise Slack notification when a channel hint is configured.
6. Persist the enriched envelope as stage output JSON — downstream investigation stages consume this schema only.

## Guardrails

- Do not resolve or close the ticket during enrichment.
- Redact customer PII from Slack messages and work notes.
