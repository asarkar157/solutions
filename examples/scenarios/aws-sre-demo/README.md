# Scenario: `aws-sre-demo`

## Pitch (read this on the call)

> "Aiden can triage and remediate an AWS incident end-to-end — read CloudWatch / EC2 state, propose a fix bounded by org policy, and (when you say go) execute the fix. Let me show you on a connected account."

## What this scenario wires

- `aios-foundation` — LLM secrets + a Guild-registered model
- `aios-policies` — `dangerous_ops` guardrail (other policies are turned off to keep the demo small)
- `aios-integration-aws` — assumes the IAM role you supply
- `aios-integration-slack` — *optional* (only created if `slack_bot_token` is set)
- `aios-agent-aws-sre` — the AWS-SRE agent itself

## Run

```bash
# Option A: from the repo root, one command
make demo SCENARIO=aws-sre-demo

# Option B: directly in this folder
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars     # fill in stackgen_token, aws_role_arn, at least one LLM key
tofu init
tofu apply
```

`tofu apply` finishes in ~2–3 minutes against an empty Guild tenant. The `next_steps` output prints the Guild URL, the agent name, and a starter prompt — paste that prompt into Guild chat to begin the demo.

## Talk track (5 bullets, ~5 minutes)

1. **Show the agent in Guild.** Point at the registered agent (`${aws_sre_agent_name}` from outputs). Explain: "this is just an `sg_agent` resource — same primitive as everything else in Guild, including the integrations and policies we just created."
2. **Type the starter prompt.** "An EC2 instance in `<region>` is unhealthy. Triage and propose a fix." Let the agent talk to the AWS MCP tool and read state.
3. **Pause on the proposed action.** The `dangerous_ops` policy gates any write. Show the policy attachment in the agent detail view — "this is what stops the agent from doing something destructive without an explicit human approval."
4. **Approve a safe action** (e.g. restart, scale). The agent reports back when complete.
5. **Show the next step**: a workflow. Open `examples/complete/main.tf` if the prospect wants the bigger picture — same modules, more wiring (Grafana, schedules, additional agents).

## Reset for the next prospect

```bash
make demo-reset SCENARIO=aws-sre-demo
```

Tears down and re-applies. Useful between back-to-back calls.

## Adjusting / extending

- Want full SRE coverage, not just AWS? Swap `aios-agent-aws-sre` for `aios-agent-sre` (5 agents, more workflows). See [`modules/aios-agent-sre/README.md`](../../../modules/aios-agent-sre/README.md).
- Want a weekly tagging audit on schedule? Add `aios-agent-schedules` (see `examples/complete/main.tf`).
- Want to leave Aiden running but capture this exact config as code for the customer? Use [`tools/aios-export/`](../../../tools/aios-export/) after apply.
