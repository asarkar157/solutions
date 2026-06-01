End-to-end ServiceNow ticket → Grafana/Prometheus + AWS investigation → bounded AWS remediation → ServiceNow closure → Slack notification pipeline for SRE ticket resolution.

## Trigger

- **Active**: ServiceNow webhook (`sg_webhook` `servicenow-ticket-receiver`) POST to StackGen when `enable_servicenow_webhook = true`.
- **Passive**: Queries mentioning ServiceNow incidents on production workloads.

## Stages

1. **ticket-ingest-filter** — Deterministic Rego policy_check on the raw webhook payload (priority, assignment group, category allowlists; blocked groups; blocked short_description substrings).
2. **enrich-ticket** — Parse ServiceNow ticket, add work notes, notify Slack, emit enriched JSON.
3. **investigate** — Query Grafana (Prometheus datasources) and AWS for root-cause evidence.
4. **propose-resolution** — Plan bounded AWS remediation with rollback and verification steps.
5. **resolution-safety-gate** — Inline Rego blocks auto-remediation when output reflects P1/Critical-class severity.
6. **resolve-and-notify** — Execute safe AWS actions, update ServiceNow, post Slack summary.
