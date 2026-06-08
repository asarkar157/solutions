# Scenario: `slo-weekly-review`

## Pitch

> "What is our error budget posture this week — and does Git still match what Grafana alerts on? Aiden reads OpenSLO from GitHub, probes Prometheus through Grafana, flags config drift, and posts a Monday digest to Slack. When you are ready, it can open a PR with new or fixed SLO definitions."

## What this scenario wires

- `aios-foundation` + `aios-policies`
- `aios-integration-github`, `aios-integration-grafana`, `aios-integration-slack`
- `aios-agent-slo-health` — review + bootstrap + drift reconcile workflows
- Weekly schedule: Monday 10:00 UTC → `slo-health-review`

## Bootstrap your OpenSLO repo

Copy the example tree from [`modules/aios-agent-slo-health/templates/openslo-examples/`](../../../modules/aios-agent-slo-health/templates/openslo-examples/) into your GitHub repo. See [`docs/OPENSLO_REPO_LAYOUT.md`](../../../modules/aios-agent-slo-health/docs/OPENSLO_REPO_LAYOUT.md).

Set in `terraform.tfvars`:

```hcl
openslo_repository_full_name = "my-org/observability"
```

## Run

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
tofu init
tofu apply
```

## Talk track (~5 minutes)

1. **Show the agent and three workflows** — review (scheduled), bootstrap (discover SLOs → PR), drift reconcile (fix Git drift → PR).
2. **Show the Monday schedule** — `0 10 * * 1` UTC on `slo-health-review`.
3. **Run review manually** — "What is our error budget posture for payments-api?"
4. **Show drift section** — config drift between OpenSLO Git and Grafana alert rules.
5. **Optional bootstrap** — "Discover SLOs from our Grafana dashboards" with `confirm_pr=true`.

## Workflows

| Workflow | Trigger | Writes Git? |
|----------|---------|-------------|
| `slo-health-review` | Schedule / chat | No |
| `slo-definition-bootstrap` | Chat / webhook | PR only |
| `slo-drift-reconcile` | Chat / webhook | PR only |

## Reset

```bash
tofu destroy
```
