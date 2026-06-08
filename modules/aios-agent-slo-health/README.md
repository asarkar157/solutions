# SLO Health Analyst — OpenSLO + Grafana

Terraform module that registers a **slo-health** Guild agent with three workflows:

| Workflow | Purpose |
|----------|---------|
| `slo-health-review` | Weekly error budget posture + config drift vs Grafana (read-only) |
| `slo-definition-bootstrap` | Discover SLOs from Grafana metrics → OpenSLO YAML → GitHub PR |
| `slo-drift-reconcile` | Deep drift analysis → reconcile PR for Git-side fixes |

## Quick start

```hcl
module "slo_health" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-slo-health?ref=main"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  openslo_repository_full_name = "my-org/observability"

  github_secret_id  = module.github_pat.secret_id
  grafana_secret_id = module.grafana_integration.secret_id
  slack_secret_id   = module.slack_integration.secret_id

  slo_report_webhook_url = var.slo_webhook_url
}
```

## OpenSLO GitHub repo layout

See [docs/OPENSLO_REPO_LAYOUT.md](docs/OPENSLO_REPO_LAYOUT.md) for the recommended tree under `openslo/slos/<service>/`.

Copy [templates/openslo-examples/](templates/openslo-examples/) into your observability repo to bootstrap.

## Config drift

See [docs/SLO_CONFIG_DRIFT.md](docs/SLO_CONFIG_DRIFT.md) for drift types, actions, and digest format.

## Prerequisites

1. OpenSLO YAML in GitHub (may start empty)
2. Grafana integration with dashboard/alert MCP + `query_metric`
3. GitHub read (review) or read+write (bootstrap/drift PR)
4. Ubuntu CLI or remote runner when PR workflows enabled
5. Optional: [Sloth](https://sloth.dev/) deployed to materialize Prometheus recording rules after merge

## Weekly schedule

Default: Monday 10:00 UTC (`0 10 * * 1`) targeting `slo-health-review`. Disable with `enable_weekly_schedule = false`.

## GitHub permissions

| Workflow | Scope |
|----------|-------|
| slo-health-review | `contents: read` |
| slo-definition-bootstrap / slo-drift-reconcile | `contents: write`, `pull_requests: write` |

## Key variables

| Variable | Default | Description |
|----------|---------|-------------|
| `openslo_repository_full_name` | (required) | GitHub org/repo for OpenSLO YAML |
| `openslo_path_prefix` | `openslo/` | Recursive scan prefix |
| `enable_slo_drift_in_review` | `true` | Drift stages in weekly review |
| `enable_slo_bootstrap_workflow` | `true` | Bootstrap workflow + runbooks |
| `enable_slo_drift_reconcile_workflow` | `true` | Drift reconcile workflow |
| `enable_ubuntu_cli` | `true` | Ubuntu sidecar for `gh pr create` |
| `enable_parallel_validate_batches` | `true` | Fan out validate-promql via spawn contracts |
| `enable_parallel_draft_batches` | `true` | Fan out draft-openslo-yaml via spawn contracts |
| `max_parallel_batches` | `4` | Max parallel validate/draft sub-agents (2–4) |

## Outputs

- `workflow_names.review`, `.bootstrap`, `.drift_reconcile`
- `schedule_names` when weekly schedule enabled
- `webhook_trigger_endpoint` when `webhook_trigger_base_url` set
