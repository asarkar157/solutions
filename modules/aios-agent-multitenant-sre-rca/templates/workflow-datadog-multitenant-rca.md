# Datadog Multi-Tenant RCA Workflow

End-to-end root-cause analysis for multi-tenant SaaS incidents triggered by Datadog monitor alerts.

## Flow

1. **alert-ingest-filter** — Deterministic Rego gate on priority, tenant_id allowlist, and blocked services/tags.
2. **normalize-alert** — Extract tenant scope from Datadog tags (key: `${tenant_tag_key}`), emit normalized_alert JSON.
3. **cross-signal-investigate** — Read-only analysis across Datadog metrics/logs, GCP Cloud Logging (${gcp_project_id}), AWS ECS deploy history, CloudTrail, and GitHub commits.
4. **synthesize-rca** — Produce structured RCA JSON with summary, timeline, root_cause, evidence_links, and tenant_impact.
5. **publish-rca-slack** — Post formatted RCA to `${slack_rca_channel}` with investigation_id for thread collaboration.

## Integrations

Datadog, GCP, AWS, GitHub (investigation); Datadog + Slack (ingest); Slack (publish).

## Evidence checklist

When enabled, proof-of-work requires: datadog_monitor_linked, timeline_documented, root_cause_stated, tenant_scope_identified.

## Collaboration

After publish, users can continue in Slack threads via the `datadog-rca-collaboration` workflow and `slack-rca-thread` webhook.
