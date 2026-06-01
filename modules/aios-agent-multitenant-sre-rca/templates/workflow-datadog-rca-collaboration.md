# Datadog RCA Collaboration Workflow

Follow-up workflow for multi-user Slack thread collaboration on completed multi-tenant RCA investigations.

## Required inputs

- `tenant_id` — Tenant scope from the original investigation (must match prior RCA).
- `investigation_id` — Stable id from the primary RCA workflow publish stage.

## Optional inputs

- `parent_workflow_ref` — Reference to the completed datadog-multitenant-rca execution.
- `slack_thread_ts` — Slack thread timestamp for in-thread replies.
- `user_question` — Follow-up question from an engineer (@-mention or webhook payload).

## Flow

1. **collaborate** — Load prior RCA context, answer the question in thread, fetch supplemental read-only evidence only when needed.

## Behavior

- Default: answer from prior investigation notes without re-running full RCA.
- Re-investigate only when the user explicitly requests it.
- Channel hint for collaboration: `${slack_collaboration_channel_hint}`.

## Webhook ingress

When `enable_slack_collaboration_webhook` is true, `slack-rca-thread` webhook targets this workflow with action text instructing thread-context continuation.
