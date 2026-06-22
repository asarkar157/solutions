---
title: Omnichannel triage
permalink: omnichannel-triage/
---

# Omnichannel triage — Gateway → aiden-router

StackGen treats **one chat surface per tenant** (Slack, Teams, Google Chat, Telegram, WhatsApp, Guild UI). Human messages ingress through the **Omnichannel Gateway**, normalize to a Standard Internal Message (SIM), and land on **`aiden-router`** (Aiden). The router cascade picks specialists; observability alerts use **webhooks** that start workflows directly.

## One Slack App per tenant

| Model | Verdict |
|-------|---------|
| Per specialist agent URL (`/agents/foo/slack/events`) | **Removed** — specialists are not chat endpoints |
| Per catalog app (separate Slack App per `stackgen-sre-app`, etc.) | **No** — catalog apps are capabilities + deep links, not chat personas |
| **One Aiden bot** → `POST /slack/events` → `aiden-router` | **Yes** |

Catalog apps ([`aios-sre-app-bindings`](../modules/aios-sre-app-bindings/README.md)) bind Datadog/AWS/GitHub into the SRE **capability**. RCA and investigation URLs appear in **egress** messages; the same Aiden bot posts updates.

## Ingress paths

```text
Human chat (Slack / Teams / GChat / …)
  → Gateway /slack/events (etc.)
  → SIM.agent_id = aiden-router
  → find_best_candidate → route_to_agent | run_workflow
  → specialists (alert-triage, SRE investigator, FinOps, …)
  → Gateway egress (thread-aware)

Automation (Grafana / Datadog / SRE app alert ingest)
  → sg_webhook / SRE app ingest
  → workflow directly (latency + Rego filters)
  → Gateway egress to #alerts
```

| Path | Register in Terraform | Slack wiring |
|------|----------------------|----------------|
| Chat (omnichannel) | **Guild Settings → Connect Slack** (StackGen app OAuth) | `{gateway}/slack/events` |
| Agent investigations (MCP) | Optional `aios-integration-slack` | Not a second Event URL — MCP tools only |
| Alerts | `sg_webhook` on Grafana/Datadog/SRE app | N/A — not Slack ingress |

**Do not** add `sg_webhook` with `source=slack` on new scenarios. Thread follow-up belongs on the Gateway session + `aiden-router`, not a parallel Slack collaboration webhook.

## Operator checklist (after `tofu apply`)

1. **Guild → Settings → Connect Slack → Add to Slack** (binds `team_id` + per-org bot token in Vault)
2. **Slack Event URL:** `https://<gateway-host>/slack/events` (shown in Settings Advanced URLs; paste into StackGen Slack app once)
3. Set `SLACK_SIGNING_SECRET` on the Gateway (StackGen-operated app)
4. Invite the Aiden bot to incident channels (e.g. `#sre-alerts`)
5. Wire Grafana/Datadog monitor webhooks to workflow or SRE app ingest URLs from scenario outputs
6. In Slack: `@Aiden investigate the firing alert` (chat path)

Optional: `aios-integration-slack` for agent MCP tool access during investigations — separate from omnichannel chat OAuth.

Optional: force a specialist without waiting for cascade — `agent:<agent-name> investigate …` in the Slack message.

## Force a specific agent

| Surface | Mechanism |
|---------|-----------|
| Guild Command Center | `@mention` one agent → `entity_refs` → direct dispatch |
| Slack (Gateway) | `agent:<name>` prefix in message text |
| Natural language | Router `find_best_candidate` or `route_to_agent` |

Rosters are live Guild state after apply — `GET /api/v1/rosters` lists agents, workflows, and integrations. No separate Terraform “roster” resource.

## Scenario outputs

Runnable roots under `examples/scenarios/` expose `gateway_slack_event_url` when `var.gateway_base_url` is set (public Gateway origin, no trailing slash).

## Related docs

- Guild Slack install: [stackgen-guild `docs/installation/slack.md`](https://github.com/appcd-dev/stackgen-guild/blob/main/docs/installation/slack.md)
- Incident triage limits: [incident-triage-poc-limits.md](incident-triage-poc-limits.md)
- SRE app bindings: [aios-sre-app-bindings README](../modules/aios-sre-app-bindings/README.md)
