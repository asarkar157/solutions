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

After apply, read PoC checklist:

```bash
cd examples/scenarios/incident-triage
tofu output poc_checklist
tofu output grafana_webhook_url
```

## Talk track (5 bullets, ~5 minutes)

1. **Open Guild and show the agent fleet.** "Three agents: ingest filter, RCA investigator with hypothesis subagents, and a coordinator for cloud escalation."
2. **Show the workflow graph.** Open `cross-platform-alert-triage` — 12 stages from Rego ingest filter through query probe, cross-signal investigation, and Slack RCA publish.
3. **Fire a synthetic alert.** Type in chat: "A Grafana alert just fired: `ServiceUnavailable` on `payments-api`. Run the full triage pipeline." Watch normalization, prior-incident search, and hypothesis branches in the trace.
4. **Show the policy gate.** `dangerous_ops` is attached on the coordinator. "Cloud escalation and remediation stay bounded; destructive ops still need human approval."
5. **Close on the Slack post.** This is what the on-call team actually sees — structured RCA with evidence, not raw Grafana noise.

## End-to-end (post-call)

The scenario registers the workflow but does **not** modify the prospect's Grafana contact points. After the call, point them at the workflow's webhook ingress URL (`tofu output grafana_webhook_url`) and walk them through adding it as a Grafana contact point. The `aios-agent-schedules` companion module is the right thing to add next if they want periodic synthetic checks.

## Incident Triage PoC runbook

Dual stack: **this Terraform scenario** (provisioning) + **stackgen-sre-app** (eval runner + Investigations UI).

### Phase 0 — Customer dataset (SE)

1. Use [`scripts/incident-worksheet.md`](./scripts/incident-worksheet.md) to extract 15–25 incidents with published RCAs.
2. Validate JSONL against [`scripts/incidents.schema.json`](./scripts/incidents.schema.json).
3. Engineering dry-run fixture: [`scripts/data/synthetic.jsonl`](./scripts/data/synthetic.jsonl).

### Phase 1 — Provision

1. Apply this scenario (`make demo SCENARIO=incident-triage`).
2. Install/reconcile **SRE Copilot** app in the same org.
3. Create Guild namespace **`shared:incidents`** and grant investigator access ([SRE app docs](https://github.com/appcd-dev/guild-apps/stackgen-sre-app/blob/main/docs/endpoints-and-guild-integration.md)).
4. Optional: run **Discovery** once from SRE app for KG enrichment.

### Phase 2 — Eval v1 (baseline)

From **stackgen-sre-app** repo:

```bash
export GUILD_URL=... STACKGEN_TOKEN=... GUILD_PROJECT_ID=...

./scripts/poc-eval/run.sh \
  --dataset /path/to/incidents.jsonl \
  --eval-run-id customer-v1-baseline
```

Merge output with [`scripts/scorecard-template.csv`](./scripts/scorecard-template.csv) human columns. Aggregate:

```bash
./scripts/aggregate-scores.sh results/scored.csv
```

Update [`docs/incident-triage-poc-taxonomy.md`](../../docs/incident-triage-poc-taxonomy.md) with category verdicts.

### Phase 3 — Memory bootstrap + eval v2

```bash
cd scripts
./bootstrap-memory.sh --dataset /path/to/incidents.jsonl --mode agent
```

Demo: Guild **Memory Explorer** → filter `shared:incidents` → show curated import provenance (`incident_id`, `approved_by`).

Re-run poc-eval with `--eval-run-id customer-v2-post-memory`. Compare aggregate lift for procurement ([`scripts/render-scorecard.md`](./scripts/render-scorecard.md)).

### Phase 4 — Live demo

1. Wire Grafana contact point to `tofu output -raw grafana_webhook_url`.
2. Open SRE app Alerts → auto-investigate or manual **Investigate**.
3. Show Investigations evidence panel + prior incidents drawer.

### Honest limits

Read [`docs/incident-triage-poc-limits.md`](../../docs/incident-triage-poc-limits.md) before customer workshops — offline vs live replay, memory layers, weak OOTB categories.

### Scripts reference

| Script | Purpose |
| ------ | ------- |
| [`build-prompt-from-row.sh`](./scripts/build-prompt-from-row.sh) | Generate `initial_prompt` from labels |
| [`bootstrap-memory.sh`](./scripts/bootstrap-memory.sh) | Import golden RCAs to `shared:incidents` |
| [`aggregate-scores.sh`](./scripts/aggregate-scores.sh) | Category rollup from human-scored CSV |
| [`render-scorecard.md`](./scripts/render-scorecard.md) | Procurement PDF template |

Batch runner lives in **stackgen-sre-app**: `scripts/poc-eval/run.sh` ([docs](https://github.com/appcd-dev/guild-apps/stackgen-sre-app/blob/main/docs/poc-eval.md)).

## Reset for the next prospect

```bash
make demo-reset SCENARIO=incident-triage
```
