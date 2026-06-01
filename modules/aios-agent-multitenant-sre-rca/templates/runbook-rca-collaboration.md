Collaborate on a completed multi-tenant RCA investigation via Slack thread follow-up.

## Prerequisites

- `tenant_id` and `investigation_id` (or `parent_workflow_ref`) from workflow trigger.
- Optional `slack_thread_ts` for in-thread replies.
- Optional `user_question` from Slack @-mention or webhook payload.

## Steps

1. Load prior RCA JSON and investigation notes for the given investigation_id.
2. Validate tenant_id matches the original investigation scope.
3. Answer `user_question` using prior evidence when sufficient — cite original evidence_links.
4. When supplemental evidence is needed, run targeted read-only queries scoped to tenant_id:
   - Datadog metric/log snapshot for a specific time range
   - GCP log query for a narrowed filter
   - CloudTrail lookup for a specific event type
   - GitHub blame on a named path
5. Do **not** re-run the full cross-signal RCA pipeline unless the user explicitly requests re-investigation.
6. Post the reply in the Slack thread (`slack_thread_ts`) or collaboration channel hint `${slack_collaboration_channel_hint}`.
7. Emit `collaboration_result` JSON with answer summary and any new evidence links.

## Multi-user behavior

- Support multiple engineers asking questions in the same thread.
- Maintain consistent investigation context across replies.
- Track when supplemental queries were run vs when prior notes sufficed.

## Guardrails

- Read-only on all cloud integrations unless user explicitly requests full re-investigation.
- Never blend tenant scopes.
- Redact PII from thread replies.
