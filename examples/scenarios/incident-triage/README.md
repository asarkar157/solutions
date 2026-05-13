# Scenario: `incident-triage`

## Pitch (read this on the call)

> "Grafana fires 200 alerts a day, your on-call mutes the channel by lunch. Aiden takes the alert, decides if it is AWS or Kubernetes or a managed service, routes the RCA to the right agent, posts the narrative to Slack — and only pages a human if the policy gate says so."

## What this scenario wires

- `aios-foundation` — LLM secrets + models
- `aios-policies` — full set (the SRE workflows expect them)
- `aios-integration-grafana` — read access to alerts + dashboards
- `aios-integration-slack` — RCA post target
- `aios-agent-sre` — 5 SRE agents (triage, change-correlation, auto-remediation, risk-posture, incident)
- `aios-agent-alert-triage` — the coordinator that routes incoming alerts

## Run

```bash
make demo SCENARIO=incident-triage
```

## Talk track (5 bullets, ~5 minutes)

1. **Open Guild and show the agent fleet.** "One coordinator (`alert-triage-coordinator`) plus a pool of specialist agents. The coordinator's job is routing, not fixing."
2. **Show the workflow graph.** Open `cross-platform-alert-triage` — the coordinator inspects alert labels, hands off to the specialist agent best matched to the service.
3. **Fire a synthetic alert.** Type in chat: "A Grafana alert just fired: `ServiceUnavailable` on `payments-api`. Triage and route the RCA." Watch the routing decision happen in front of the prospect.
4. **Show the policy gate.** `dangerous_ops` + `prod_write_gate` are attached. "Auto-remediation can propose a fix; a human still approves anything destructive."
5. **Close on the Slack post.** This is what the on-call team actually sees. Compare it to the noise they get from Grafana today.

## End-to-end (post-call)

The scenario registers the workflow but does **not** modify the prospect's Grafana contact points. After the call, point them at the workflow's webhook ingress URL (visible in Guild) and walk them through adding it as a Grafana contact point. The `aios-agent-schedules` companion module is the right thing to add next if they want periodic synthetic checks.

## Reset for the next prospect

```bash
make demo-reset SCENARIO=incident-triage
```
