Multi-source runbook routing for PrivateSaaS SRE.

## Module SOP catalog

${module_runbook_catalog}

## External operator catalog (Terraform `external_runbook_catalog`)

${external_runbook_catalog_markdown}

## Steps

1. Score module SOPs by keyword overlap with `service`, `alert_name`, and symptom tokens.
2. Fetch FireHydrant linked runbooks for the active incident id.
3. Search internal tooling for catalog entries (ownership, dependencies, runbook tags).
4. Merge external catalog URLs when descriptions match.
5. Output `matched_runbooks` with ordered steps and confidence scores.
6. List `coverage_gaps` when no source exceeds the confidence threshold.

## Guardrails

- Cite source name and URL for every matched step.
- Do not fabricate procedures.
