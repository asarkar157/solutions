# SLO config drift

How **`aios-agent-slo-health`** compares Git OpenSLO definitions to live Grafana alert rules and dashboard panels.

## Drift types

| Type | Detection | Example |
|------|-----------|---------|
| `query_drift` | OpenSLO PromQL ≠ closest alert/dashboard expr | Git uses `service=`; alert uses `job=` |
| `target_drift` | Objective target ≠ implied alert threshold | SLO 99.9% but alert at 99% errors |
| `coverage_gap` | Alert/dashboard signal with no OpenSLO file | New `HighErrorRate` rule last week |
| `orphan_slo` | Git SLO with no Grafana link / empty queries | Deprecated service still in repo |
| `burn_window_misalignment` | Single-threshold alert vs multi-window SLO | Missing 1h/6h burn alerts |
| `equivalent` | Semantically matching queries | No action (`IGNORE`) |

## Recommendation actions

| Action | Module behavior |
|--------|-----------------|
| `UPDATE_GIT` | Patch OpenSLO YAML in reconcile PR (trust Grafana) |
| `ADD_SLO` | Add new YAML file in reconcile or bootstrap PR |
| `DEPRECATE_GIT` | Remove/archive stale YAML in reconcile PR |
| `SUGGEST_GRAFANA_CHANGE` | Read-only suggestion in digest — Git is source of truth |
| `IGNORE` | Listed but no PR change |

## Weekly digest section

The **`compose-slo-digest`** runbook renders:

1. **Error budget this week** — posture per SLO
2. **Config drift** — `actionable_count` and top items by severity
3. **Next steps** — link to `slo-drift-reconcile` when enabled

## JSON contract: `slo_drift_report`

```json
{
  "summary": {
    "total_slos_in_git": 8,
    "drifted": 3,
    "coverage_gaps": 2,
    "orphans": 1,
    "actionable_count": 4
  },
  "items": [
    {
      "slo_name": "payments-api-availability",
      "drift_type": "query_drift",
      "recommended_action": "UPDATE_GIT",
      "git_path": "openslo/slos/payments-api/availability.yaml",
      "suggestion_plain": "Update PromQL to match on-call alert rule.",
      "severity": "medium"
    }
  ]
}
```

## Grafana mutations

The module **never** edits Grafana. `SUGGEST_GRAFANA_CHANGE` items appear as text recommendations only.
