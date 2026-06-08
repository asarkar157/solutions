# OpenSLO GitHub repository layout

This document defines how to structure the observability Git repo consumed by **`aios-agent-slo-health`**.

## Recommended tree

```
my-org/observability/                    # openslo_repository_full_name
├── README.md
├── openslo/                             # openslo_path_prefix (default)
│   ├── dataproviders/
│   │   └── prometheus-default.yaml
│   ├── slos/
│   │   ├── payments-api/
│   │   │   ├── availability.yaml
│   │   │   └── latency-p99.yaml
│   │   └── checkout-api/
│   │       └── availability.yaml
│   └── slis/                            # optional standalone SLIs
├── sloth/
│   └── sloth.yml                        # optional — customer runs Sloth
└── .github/workflows/
    └── validate-openslo.yml             # optional CI validation
```

## Conventions

| Rule | Rationale |
|------|-----------|
| One `kind: SLO` per file under `openslo/slos/**` | Clear diffs and ownership |
| Kebab-case filenames by signal (`availability.yaml`, `latency-p99.yaml`); `metadata.name` is the stable SLO id (`<service>-<signal>`) | Clear diffs; agent proposes paths under `openslo/slos/<service>/` |
| Folder per service | Scales to many SLOs |
| Explicit `service` / `job` labels in PromQL | Agent can scope Grafana queries |
| Skip `_*.yaml` and `README.md` | Helpers not ingested as SLOs |

## Minimum SLO document

```yaml
apiVersion: openslo/v1
kind: SLO
metadata:
  name: payments-api-availability
  displayName: Payments API — 30d availability
  labels:
    service: payments-api
    team: payments
    tier: tier-1
spec:
  description: Non-5xx HTTP responses over rolling 30 days
  service: payments-api
  budgetingMethod: Occurrences
  timeWindow:
    - duration: 30d
      isRolling: true
  indicator:
    metadata:
      name: payments-api-availability
    spec:
      ratioMetric:
        counter: true
        good:
          metricSource:
            type: Prometheus
            spec:
              query: sum(rate(http_requests_total{service="payments-api",status!~"5.."}[5m]))
        total:
          metricSource:
            type: Prometheus
            spec:
              query: sum(rate(http_requests_total{service="payments-api"}[5m]))
  objectives:
    - displayName: 99.9% availability
      target: 0.999
```

## Sloth deployment (customer-side)

1. Commit OpenSLO YAML to Git (layout above).
2. Run [Sloth](https://sloth.dev/) or the Sloth Kubernetes controller to generate Prometheus recording rules and multi-window burn alerts.
3. Wire Terraform vars: `openslo_repository_full_name`, `openslo_path_prefix`, `openslo_branch`.
4. Guild **reads** specs from Git and **measures** via Grafana (Sloth metrics when present).

Preferred Sloth metric names:

- `slo:sli_error:ratio_rate5m{sloth_service="...", sloth_slo="..."}`
- `slo:period_error_budget_remaining:ratio{...}`

If Sloth is not deployed, the slo-health agent falls back to OpenSLO `ratioMetric` queries via Grafana `query_metric`.

## Bootstrap and drift PRs

- **`slo-definition-bootstrap`** writes new files under `openslo/slos/<service>/` via PR.
- **`slo-drift-reconcile`** patches or removes files when Grafana alerts/dashboards drift from Git.

Never push directly to the default branch — all writes go through PR review.
