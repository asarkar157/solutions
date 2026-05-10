# AIOS Agent — Langfuse AI Quality Observer

Cross-domain observability agent that combines **Langfuse** LLM trace analytics with optional **Grafana** infrastructure metrics and **any other Guild integrations** you attach (Slack, Linear, GitHub, clouds, ClickHouse, etc.) to produce an AI Operations Health Scorecard.

## Real-World Scenario

An AI platform team notices agents producing lower quality outputs. Is it a prompt regression (visible in Langfuse quality scores) or infrastructure pressure (visible in Grafana CPU/memory metrics)? This module answers that question by correlating both data sources when Grafana is wired—and still delivers a Langfuse-first scorecard when it is not.

## What it provisions

- **Agent**: configurable name (default `langfuse-ai-quality-observer`) with a read-only, multi-integration persona
- **4 Runbook SOPs**: trace collection, reliability scoring, correctness scoring, cross-domain correlation (wording adapts if Grafana is absent)
- **Workflow**: configurable name (default `ai-ops-health-scorecard`) — 5-stage DAG producing a letter-graded scorecard (A–F)

## Workflow Architecture

```
collect-traces
    ├── score-reliability
    └── score-correctness
              ↓
    cross-domain-correlation  (Langfuse + Grafana when grafana is set; otherwise Langfuse-led synthesis)
              ↓
    compile-scorecard → Letter-graded report card
```

## Usage

`integration_names` is a **map**: it must include `langfuse`. Any other keys attach integrations on the same agent in stable order (langfuse first, then alphabetical by key).

```hcl
module "langfuse_observer" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-langfuse-observer"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops          = module.policies.policy_ids.dangerous_ops
    data_risk_pii          = module.policies.policy_ids.data_risk_pii
    langfuse_observability = module.policies.policy_ids.langfuse_observability
  }

  integration_names = {
    langfuse = module.langfuse_integration.integration_name
    grafana  = module.grafana_integration.integration_name # optional; enables infra correlation text in runbooks
    slack    = module.slack_integration.integration_name     # optional; digest / escalation context
    github   = module.github_integration.integration_name  # optional; link regressions to commits/releases
    # linear = module.linear_integration.integration_name
    # aws    = module.aws_integration.integration_name
    # gcp    = module.gcp_integration.integration_name
    # clickhouse = module.clickhouse_integration.integration_name
  }

  # Optional: second instance in the same project (unique names + runbook prefix)
  # agent_name          = "langfuse-observer-team-b"
  # workflow_name       = "ai-ops-scorecard-team-b"
  # runbook_name_prefix = "langfuse-team-b"
}
```

## Composition patterns (Langfuse + other integrations)

| You attach | Typical use in scorecard workflows |
|------------|-------------------------------------|
| **Grafana** | Infra correlation: CPU/memory/restarts vs trace latency and errors (default narrative in runbooks). |
| **Slack** | Post weekly scorecard summary to `#ai-platform`, thread drill-down links. |
| **Linear** | Open follow-up issues for sustained low correctness or cost anomalies. |
| **GitHub** | Tie quality regressions to merges, releases, or workflow runs in the evaluation window. |
| **AWS / GCP** | Cross-check cost or capacity signals with Langfuse token spend (FinOps-style). |
| **ClickHouse** | Join internal analytics or feature-store metrics with trace metadata when IDs align. |

Policies still apply: the Langfuse observability policy keeps Langfuse mutations blocked; other integrations follow their own policy attachments in your stack.

## Outputs

| Name | Description |
|------|-------------|
| `agent_name` | Name of the observer agent |
| `workflow_name` | Name of the AI Ops Health Scorecard workflow |
| `observer_integration_names` | Resolved list of integration names on the agent (for debugging wiring) |
