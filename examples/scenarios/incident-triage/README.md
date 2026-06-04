# Scenario: `incident-triage`

## Pitch (read this on the call)

> "Grafana fires 200 alerts a day, your on-call mutes the channel by lunch. Aiden ingests the alert through a Rego filter, searches prior incidents, probes the PromQL behind the rule, runs ReAcTree hypothesis branches, synthesizes an RCA, and posts the narrative to Slack — escalating to cloud specialists only when the signal warrants it."

## What this scenario wires

- `aios-foundation` — LLM secrets + models
- `aios-policies` — full set (the SRE workflows expect them)
- `aios-integration-grafana` — read access to alerts + dashboards
- `aios-integration-slack` — RCA post target
- `aios-agent-sre` — 5 SRE agents (triage, change-correlation, auto-remediation, risk-posture, incident)
- `aios-agent-alert-triage` — Grafana alert ingest, 12-stage RCA pipeline (prior-incident memory, query probe, hypothesis tree, Slack publish)

## Run

```bash
make demo SCENARIO=incident-triage
```

## Talk track (5 bullets, ~5 minutes)

1. **Open Guild and show the agent fleet.** "Three agents: ingest filter, RCA investigator with hypothesis subagents, and a coordinator for cloud escalation."
2. **Show the workflow graph.** Open `cross-platform-alert-triage` — 12 stages from Rego ingest filter through query probe, cross-signal investigation, and Slack RCA publish.
3. **Fire a synthetic alert.** Type in chat: "A Grafana alert just fired: `ServiceUnavailable` on `payments-api`. Run the full triage pipeline." Watch normalization, prior-incident search, and hypothesis branches in the trace.
4. **Show the policy gate.** `dangerous_ops` is attached on the coordinator. "Cloud escalation and remediation stay bounded; destructive ops still need human approval."
5. **Close on the Slack post.** This is what the on-call team actually sees — structured RCA with evidence, not raw Grafana noise.

## End-to-end (post-call)

The scenario registers the workflow but does **not** modify the prospect's Grafana contact points. After the call, point them at the workflow's webhook ingress URL (visible in Guild) and walk them through adding it as a Grafana contact point. The `aios-agent-schedules` companion module is the right thing to add next if they want periodic synthetic checks.

## Reset for the next prospect

```bash
make demo-reset SCENARIO=incident-triage
```
