Probe Grafana datasource health for alert-triage clarity checks.

## Steps

1. **`execute_command`**: `gcx datasources list -o json` — enumerate configured datasources.
2. Identify the datasource UID/name used by the firing alert rule (from `get_alert_rule` output).
3. Flag datasources that are missing, mis-typed, or report connectivity errors.
4. When rule datasource differs from dashboard panel datasource hints, note `datasource_mismatch`.
5. Emit `datasource_probe` JSON:

```json
{
  "healthy": true,
  "rule_datasource_uid": "...",
  "failing_uids": [],
  "notes": "..."
}
```

## Guardrails

- Read-only — no datasource configuration changes.
- Treat probe failures as observability issues until infra evidence contradicts.
