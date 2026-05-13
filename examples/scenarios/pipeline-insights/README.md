# Scenario: `pipeline-insights`

## Pitch (read this on the call)

> "You probably have a Datadog or Grafana dashboard that tells you what failed. Aiden tells you *why* — which PR, who merged it, what changed since the last green deploy. It is read-only, so I can demo it without your prod credentials."

This is the **safest** first demo: no AWS, no Slack write side-effects, no policy gates to explain. Use it when you do not yet have the prospect's prod creds.

## What this scenario wires

- `aios-foundation` — LLM secrets + models
- `aios-policies` — minimal policy set (`dangerous_ops` only is required)
- `aios-integration-github` — read-only GitHub PAT
- `aios-integration-slack` — *optional* (Slack post when configured)
- `aios-agent-pipeline-insights` — agent + `github-pipeline-insights` workflow
- `aios-agent-release-tracker` — agent + `microservice-release-tracking` workflow

## Run

```bash
make demo SCENARIO=pipeline-insights
```

## Talk track (5 bullets, ~5 minutes)

1. **Open Guild and point at both agents.** "Two agents, one GitHub integration — same pattern as everything else in the platform."
2. **Ask pipeline-insights:** "Show me the last 5 deployments to production and the PRs that drove them." Watch it call the GitHub API and produce a narrative, not a JSON dump.
3. **Drill into one deployment.** "Who approved this and when?" — the PR-merge-intelligence runbook surfaces author, reviewer, merge mode (squash / rebase), scope.
4. **Switch to release-tracker.** "What is the latest tag on `<their repo>` and is it the version we are running?" Demonstrates the deployed-version-correlation flow.
5. **Tease the schedule story** (without enabling it on the call): "This same workflow runs on a Monday morning cron and posts the digest to Slack. Want to see [`finops-weekly`](../finops-weekly/) next — same pattern for cloud spend?"

## Reset for the next prospect

```bash
make demo-reset SCENARIO=pipeline-insights
```

## Adjusting / extending

- Prefill `service_catalog` to let the prospect ask `"what is deployed for checkout-api?"` without naming the repo.
- Set `enable_slack_webhook = true` on the pipeline-insights module (edit `main.tf`) if the prospect wants a Slack mention bridge.
- Pair with `examples/scenarios/aws-sre-demo/` once the prospect is ready to wire credentials in.
