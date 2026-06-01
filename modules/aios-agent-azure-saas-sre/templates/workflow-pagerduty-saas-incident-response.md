End-to-end PagerDuty → Datadog/Azure investigation → Confluence runbook → Azure Automation remediation pipeline for single-tenant Azure SaaS.

## Trigger

- **Active**: PagerDuty webhook (`sg_webhook`) POST to StackGen when `enable_pagerduty_webhook = true`.
- **Passive**: Queries mentioning PagerDuty incidents on Azure SaaS workloads.

## Stages

1. **alert-ingest-filter** — Deterministic Rego policy_check on the raw webhook payload (priority, service, environment allowlists; blocked services).
2. **normalize-alert** — Parse PagerDuty event, enrich with incident metadata, emit normalized JSON for downstream stages.
3. **auto-investigate** — Query Datadog metrics/logs/traces and Azure resource health for the affected tenant component.
4. **match-confluence-runbook** — Search Confluence (`confluence_space_key`) for the operational runbook and extract Azure Automation runbook name/parameters.
5. **remediation-safety-gate** — Inline Rego blocks auto-remediation when investigation output reflects P1/SEV1-class severity.
6. **execute-azure-remediation** — Start the matched Azure Automation runbook with scoped parameters; verify post-action health.

## Azure Automation hints

When set, `azure_automation_account_name`, `azure_automation_resource_group`, and `azure_automation_runbook_name_hints` are injected into runbook SOP context so agents do not guess account names at runtime.
