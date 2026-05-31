# AIOS Agent — GitHub Pipeline & Deployment Intelligence

Read-only conversational agent that answers questions about CI/CD state, PR merges, and deployment outcomes by querying the GitHub integration. Useful for on-call SREs ("did the deploy go through?"), release managers ("who merged this?"), and engineers ("why did CI fail on my branch?").

## Usage

```hcl
module "pipeline_insights" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-pipeline-insights"

  # aios-foundation exposes model_names as list(string) — pass it through.
  # To hand-pick: model_names = [module.foundation.model_names_by_provider.claude_sonnet]
  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    github = module.github_integration.integration_name
    slack  = module.slack_integration.integration_name
  }

  # Optional: open a webhook for a Slack-mention bridge to fire the workflow
  enable_slack_webhook = false
}
```

## What It Creates

- **1 agent**: `pipeline-insights` (GitHub + optional Slack)
- **3 runbook SOPs**: `workflow-run-status-lookup`, `pr-merge-intelligence`, `deployment-status-lookup`
- **1 workflow**: `github-pipeline-insights` (intent-classified, fan-out to the three lookup runbooks, then composes a linked Markdown answer)
- **0–1 webhooks**: `slack-pipeline-insights` (only when `enable_slack_webhook = true`)

## What it answers

- "Did the latest CI run on `<repo>` `<branch>` pass?" — workflow runs, conclusions, failing step + log excerpt.
- "Who merged PR #N in `<repo>`?" — `merged_by`, `merged_at`, mode (squash / merge / rebase), reviewers, change scope, linked issues.
- "What's the latest deploy on `<env>` for `<service>`? Did it succeed?" — most recent deployments + deployment_statuses, with failure log links.
- "Show me recent merges into `main` since yesterday." — batch PR digest with author / merger / scope.

Always includes the GitHub `html_url` so the operator can click through.

## StackGen deployment catalog (future)

This module is GitHub-centric today. Provider **v0.1.21+** adds read-only `data.sg_app` / `data.sg_apps` for Guild deployment-catalog apps (`integrations`, installed versions). A follow-up could optionally cross-check GitHub deployment refs against catalog `app_version` — see `aios-agent-release-tracker` (`enable_stackgen_deployment_catalog`) for the first wiring pattern.

## Why this is read-only

- `hitl.always_allowed` lists only lookup-shaped tools (`web_search`, `note`, `read_notes`).
- The `dangerous-ops` policy is attached so any attempt to dispatch a workflow run, comment on a PR, or trigger a deployment requires HITL approval.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `model_names` | yes | — | `list(string)` of registered model names in priority order; passed straight to `sg_agent.model_names` |
| `policy_ids` | yes | — | Must include `dangerous_ops` |
| `integration_names` | yes | — | Must include `github`; `slack` optional |
| `agent_budget` | no | `8` | Daily $ budget for the agent |
| `deployments_limit` | no | `10` | Default page size for deployment history per environment |
| `enable_slack_webhook` | no | `false` | Create a Slack-bridge `sg_webhook` ingress |
| `workflow_skill_refs` | no | `{}` | Optional `skill_refs` overrides per `<workflow>::<stage>` |

## Outputs

| Name | Description |
|------|-------------|
| `agent_name` | Guild name of the agent |
| `workflow_name` | Workflow name; pass to `aios-agent-schedules` for periodic CI/deploy reports |
| `runbook_names` | All registered runbook SOP names |
| `webhook` | `{ id, token }` (sensitive); `null` unless `enable_slack_webhook = true` |

## Schedule examples

Periodic CI/deploy digest using `aios-agent-schedules`:

```hcl
module "pipeline_insights_schedules" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-schedules"

  target_type = "workflow"
  target_name = module.pipeline_insights.workflow_name

  schedules = [
    {
      name       = "daily-prod-deploy-digest"
      expression = "0 16 * * *" # 16:00 UTC every day
      action     = "Summarize the last 24h of production deployments across appcd-dev/solutions and appcd-dev/payments. Group by repository, show success/failure counts and link any failed deploy to its log."
    },
    {
      name       = "morning-ci-health"
      expression = "0 14 * * 1-5" # 14:00 UTC weekdays
      action     = "List failing workflow runs on default branches across the configured org repos in the last 12 hours. Include actor, failing step, and run URL."
    },
  ]
}
```
