Operational guidance for reducing Grafana alert storms (human-applied; not executed by agents).

## Recommendations

1. **Inhibition rules** — Suppress downstream warning alerts when a critical upstream infrastructure alert fires (same `cluster` + `namespace`). See [Grafana inhibition rules](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/inhibition-rules/).
2. **Notification grouping** — Group by `alertname + namespace + cluster` to avoid per-pod pages. Configure at alert source notification policies.
3. **IRM grouping** — Keep Alertmanager `groupKey` template default for auto-resolution compatibility.
4. **Test routing** — Use `alertmanager-routing-tests` before promoting inhibition changes.

## When to apply

- Chronic alert storms (>50 alerts/hour on correlated failures)
- Symptom alerts paging before cause alerts during cascades

Agents document these recommendations in RCA `recommended_next_steps` when storm_context indicates correlated groups — agents do NOT mutate Alertmanager config.
