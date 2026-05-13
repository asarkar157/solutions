# Scenario: `finops-weekly`

## Pitch (read this on the call)

> "Most FinOps tools tell you *what* is expensive. Aiden tells you that **and** runs every Monday, posts a one-paragraph executive summary to Slack, and proposes the cleanup — gated by policy so nothing destructive ships without a human. Let me show you."

## What this scenario wires

- `aios-foundation` — LLM secrets + models
- `aios-policies` — full guardrail set (the cleanup workflow needs `dangerous_ops` + several extras)
- `aios-integration-aws` — read access to billing + EC2 / S3 / Lambda / EBS state
- `aios-integration-slack` — required for the weekly summary
- `aios-agent-cost-optimizer` — the FinOps agent + `finops-review` workflow
- `aios-agent-resource-janitor` — detection workflow (read-only) + cleanup workflow (HITL-gated, **not scheduled**)
- `aios-agent-schedules` (×2) — Monday 08:00 UTC sweep + Monday 09:00 UTC FinOps review

## Run

```bash
make demo SCENARIO=finops-weekly
```

Or manually:

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars     # fill in stackgen_token, slack_bot_token, aws_role_arn, at least one LLM key
tofu init
tofu apply
```

## Talk track (5 bullets, ~5 minutes)

1. **Show the two agents in Guild.** Point out that they share the same AWS integration — "the platform is composable; you wire integrations once, agents borrow them."
2. **Show the schedules.** Open the sg_agent_schedule list — "this is the weekly cadence customers actually want; no separate cron infra to manage."
3. **Run the FinOps workflow manually.** Type "Run the weekly FinOps review now" into the cost optimizer agent. Watch it call the AWS MCP, summarize spend / idle / rightsizing / anomalies, and post to Slack.
4. **Show the policy gate.** The janitor's **cleanup** workflow is registered but not on a schedule by default. Open the cleanup workflow's evidence checklist and the `dangerous_ops` policy attachment — "this is what stops it from quarantining buckets in production without an approval."
5. **Show the customer the executive summary in Slack.** That is the artifact their CFO will actually read.

## Reset for the next prospect

```bash
make demo-reset SCENARIO=finops-weekly
```

## Adjusting / extending

- Replace `aws` with `azure` or `gcp` in `integration_names` to demo on a different cloud (modules are symmetric).
- Tighten / loosen `inactivity_days` if the prospect's environment churns faster or slower.
- Want the cleanup workflow on a schedule too? Add a third `aios-agent-schedules` block targeting `module.resource_janitor.workflow_names.cleanup` — and explain the dwell-window safety mechanism while you do it.
- Move from "demo" to "production"? Run [`tools/aios-export/`](../../../tools/aios-export/) to capture the exact tenant state into the customer's repo.
