Match an operational runbook in Confluence and extract Azure Automation execution metadata.

## Prerequisites

- Confluence integration with access to space `${confluence_space_key}`.
- `investigation_report` and `normalized_alert` from prior stages.
- Optional `azure_automation_runbook_name_hints` map for keyword → runbook name shortcuts.

## Steps

1. Build search terms from alert title, service name, remediation category, and top hypothesis text.
2. Search Confluence in space `${confluence_space_key}` for pages tagged or titled as runbooks/playbooks.
3. Rank matches; prefer pages with an **Azure Automation** section listing account, resource group, runbook name, and parameters.
4. Parse the winning page for:
   - `runbook_name` (Azure Automation)
   - `parameter_map` (JSON object)
   - pre-checks and rollback notes
5. Cross-check against `azure_automation_runbook_name_hints` when the page is ambiguous.
6. Emit `confluence_match` JSON: `page_id`, `page_title`, `runbook_name`, `parameters`, `confidence`.

## Guardrails

- Read-only in Confluence; never edit runbook pages during incident response.
- If no confident match, set `confidence < 0.5` and recommend human escalation instead of automation.
