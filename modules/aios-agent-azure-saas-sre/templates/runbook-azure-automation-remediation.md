Execute an Azure Automation runbook for SaaS incident remediation with HITL gates and post-action verification.

## Prerequisites

- `confluence_match` JSON with `runbook_name` and `parameters`.
- Azure integration with permission to start Automation jobs (subject to Guild policies).
- Automation account `${azure_automation_account_name}` in resource group `${azure_automation_resource_group}` when configured.

## Steps

1. **Preflight** — Confirm remediation-safety-gate passed and severity is not P1/SEV1 unless human approval is recorded.
2. **Parameterize** — Merge Confluence parameter map with tenant-specific values from `normalized_alert` (subscription, resource group, app name).
3. **Start job** — Invoke `az automation runbook start` (or equivalent Azure integration tool) with scoped parameters; capture job id.
4. **Monitor** — Poll job status until completion or timeout; collect output streams.
5. **Verify** — Re-query Datadog SLIs and Azure health for the affected service; confirm alert recovery or document residual risk.
6. **Document** — Append PagerDuty note summarizing action, job id, outcome, and rollback instructions.

## Guardrails

- Single-tenant scope only — never pass wildcard subscription or cross-tenant parameters.
- Abort when blast radius exceeds one customer tenant without explicit approval.
- Prefer dry-run or `-WhatIf` style validation when the runbook supports it.
