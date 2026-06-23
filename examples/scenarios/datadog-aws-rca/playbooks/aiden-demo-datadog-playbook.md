# aiden-demo — Datadog service reference playbook

> **Purpose:** Give investigators (human or agent) enough context to interpret alerts, logs, and traces from the **aiden-demo** workshop stack on EKS (`developer-eks`, namespace `aiden-demo`, Datadog **US3**, `env:demo`).

---

## Overview

**aiden-demo** is a four-service demo mesh used with the `datadog-aws-rca` scenario and **stackgen-sre-app** investigations. All workloads emit **structured JSON logs to stdout** (file-tailed by the in-cluster Datadog Agent). **order-service** orchestrates checkout over gRPC to **product-catalog-service**, **ad-service**, and **payment-service**.

A **chaos-monkey** Deployment (`aiden-chaos-monkey`) randomly drives traffic at unpredictable intervals — do not assume errors align to clock boundaries.

| Item | Value |
|------|--------|
| K8s namespace | `aiden-demo` |
| Datadog env tag | `demo` |
| Primary APM entry | `order-service` |
| Golden schema fault file | `stackgen-demo/order-service` → `cmd/initdb/main.go` |
| Chaos control | `kubectl -n aiden-demo scale deployment/aiden-chaos-monkey --replicas=0` |

---

## Service topology

```text
aiden-chaos-monkey
    │  (HTTP checkout_saga OR isolated leaf faults)
    ▼
order-service ──gRPC──► product-catalog-service  (GetProduct, :3550)
    │              └──► ad-service               (GetAds, :8080)
    │              └──► payment-service          (Charge, :50051)
    └── SQLite (orders DB)
```

**Healthy checkout trace shape:** `order-service` parent span with children across **catalog → ad → payment** (≥4 spans, shared `trace_id` in logs via `@dd.trace_id`).

**Leaf services** (no outbound RPC in demo): `payment-service`, `product-catalog-service`, `ad-service` — errors are usually upstream-driven or env-gated local faults.

---

## Per-service quick reference

### order-service

| Field | Detail |
|-------|--------|
| `DD_SERVICE` / monitor tag | `order-service` |
| Protocol | HTTP `POST /api/orders` |
| Fault header | `X-Demo-Fault`: `healthy`, `schema`, `dependency`, `timeout`, `locked`, `panic` |
| Downstream env | `PAYMENT_GRPC_ADDR`, `CATALOG_GRPC_ADDR`, `AD_GRPC_ADDR` |
| Log contract | JSON stdout with `error.kind`, `dd.trace_id` |

| Fault mode | Real behavior | Trace / log hint |
|------------|---------------|------------------|
| `healthy` | Full checkout chain | Multi-hop flame graph |
| `dependency` | Payment unavailable / gRPC error | Child span fails on `payment-service` |
| `timeout` | Short deadline on `Charge` | Timeout on payment child |
| `schema` | Local DB insert only (skips downstream) | Single-service span; `DatabaseSchemaMismatch` |
| `locked` / `panic` | Failure local to order | Order-only errors |

**Agent hint:** Schema incidents → inspect `cmd/initdb/main.go` and SQLite migration vs insert columns. Dependency/timeout → start at payment gRPC health and network policy.

### payment-service

| Field | Detail |
|-------|--------|
| `DD_SERVICE` | `payment-service` |
| Protocol | gRPC `Charge` |
| Env faults | `PAYMENT_FAILURE_FRACTION`, `PAYMENT_DEMO_FAULT=invalid_card\|expired_card\|logic_bug` |
| Log `error.kind` | `PaymentFailure`, `InvalidCard`, `PaymentLogicBug` (logic_bug demo) |

**Agent hint:** Leaf service — if order shows dependency fault, verify payment pods, gRPC port `50051`, and recent charge payloads (invalid/expired card). **`logic_bug`** rejects **valid** Visa/Mastercard with `PaymentLogicBug` — closed-loop PR candidate on `charge.js`, not input validation.

### Closed-loop remediation matrix

| Demo command | Service | `error.kind` | Fix file | GitHub PR? |
|--------------|---------|--------------|----------|------------|
| `fire-pr-demo` / `fire-schema` | order-service | `DatabaseSchemaMismatch` | `cmd/initdb/main.go` | **Yes** |
| `fire-payment-bug` | payment-service | `PaymentLogicBug` | `charge.js` | **Yes** (after image deploy) |
| chaos `invalid_card` / AIDEN-002 | payment-service | `InvalidCard` | — | **No** (expected validation) |
| `fire-rank-commit` | product-catalog-service | `CatalogRankIndexPanic` | `main.go` rank path | Maybe (deploy regression) |

**Reproducible PR demo (order-service):**

```bash
./scripts/run-incident-triage-demo.sh fire-pr-demo
```

**Payment logic_bug PR demo:**

```bash
# Build/push payment image first (payment-service repo)
PUSH=true ./scripts/deploy-aiden-demo.sh
# Then from order-service repo:
./scripts/run-incident-triage-demo.sh fire-payment-bug
```

### product-catalog-service

| Field | Detail |
|-------|--------|
| `DD_SERVICE` | `product-catalog-service` |
| Protocol | gRPC `GetProduct` (:3550) |
| Env faults | `CATALOG_DEMO_FAULT=feature\|rank`, `CATALOG_FAILURE_FRACTION` |
| Log `error.kind` | `CatalogFeatureFailure`, `CatalogRankIndexPanic`, `CatalogLoadFailure` |

**Agent hint:** Rank panic path often tied to product ID `OLJCESPC7Z` or random IDs under rank fault mode. Feature failure is env-gated.

### ad-service

| Field | Detail |
|-------|--------|
| `DD_SERVICE` | `ad-service` |
| Protocol | gRPC `GetAds` (:8080) |
| Env faults | `AD_FAILURE_FRACTION`, `AD_DEMO_FAULT=high_cpu\|manual_gc` |
| Log `error.kind` | `AdServiceUnavailable` (and related) |

**Agent hint:** Java / log4j JSON layout — correlate with order checkout personalization step.

### aiden-chaos-monkey

| Field | Detail |
|-------|--------|
| `DD_SERVICE` | `aiden-chaos-monkey` |
| Role | Random sleep (45s–8m), weighted `checkout_saga` vs isolated leaf faults |
| Log fields | `chaos_mode`, `chaos_target`, `chaos_fault`, `chaos_result` |

**Agent hint:** Correlating incident timing with monkey logs explains “random” multi-service spikes. Pause monkey before blaming app regressions.

---

## Observability queries

Use **US3** (`us3.datadoghq.com`). Prefer `env:demo` and the service name from the alert.

### Error logs by service

```
service:order-service env:demo status:error
```

```
service:order-service env:demo @error.kind:DatabaseSchemaMismatch
```

```
service:payment-service env:demo @error.kind:PaymentFailure
```

```
service:product-catalog-service env:demo @error.kind:CatalogRankIndexPanic
```

```
service:ad-service env:demo @error.kind:AdServiceUnavailable
```

```
service:aiden-chaos-monkey env:demo
```

### Trace search

```
service:order-service env:demo
```

Look for traces with **≥3 child spans** on healthy checkout. Filter failing traces by `error` on `payment-service` or `product-catalog-service`.

### Log–trace correlation

```
service:order-service env:demo @dd.trace_id:<trace_id_from_apm>
```

Repeat for child services with the same `trace_id`.

### Service map validation

Expect edges: `order-service` → `payment-service`, `product-catalog-service`, `ad-service`. Missing edges usually mean checkout orchestration not exercised or trace propagation misconfigured (`DD_TRACE_PROPAGATION_STYLE=datadog,tracecontext`).

---

## Chaos monkey behavior

```text
loop forever:
  sleep random(CHAOS_MIN_INTERVAL_SEC .. CHAOS_MAX_INTERVAL_SEC)   # default 45–480s
  mode = weighted_pick(checkout_saga=60%, isolated=40%)
  if checkout_saga:
    POST order-service /api/orders with X-Demo-Fault: healthy|dependency|timeout
  else:
    random leaf fault on payment | catalog | ad
  emit JSON log with chaos_* fields
```

| Env (monkey Deployment) | Default | Meaning |
|-------------------------|---------|---------|
| `CHAOS_MIN_INTERVAL_SEC` | `45` | Min sleep between attacks |
| `CHAOS_MAX_INTERVAL_SEC` | `480` | Max sleep (8 min) |
| `CHAOS_BURST_SIZE` | `1` | Requests per wake |
| `CHAOS_ENABLED` | `true` | Kill switch |
| `ORDER_SERVICE_URL` | `http://aiden-demo` | In-cluster HTTP base |

**Monkey does not patch Deployments** — only sends traffic. Complex catalog/ad modes need env enabled on those Deployments plus monkey traffic.

**Reproducible demo fault (not random):**

```bash
# In stackgen-demo/order-service repo
./scripts/run-incident-triage-demo.sh fire-schema
```

---

## Fault matrix (monkey + headers)

| Target | Protocol | Simple faults | Complex faults |
|--------|----------|---------------|----------------|
| order-service | HTTP | `healthy` baseline | `schema`, `dependency`, `timeout`, `locked`, `panic` via `X-Demo-Fault` |
| payment-service | gRPC `Charge` | invalid/expired card | `PAYMENT_FAILURE_FRACTION` bursts |
| product-catalog-service | gRPC `GetProduct` | unknown product ID | `OLJCESPC7Z`, rank panic env |
| ad-service | gRPC `GetAds` | empty context | `AD_FAILURE_FRACTION` / CPU modes |

---

## Investigation playbook (agent steps)

### When `order-service` fires

1. Confirm alert tags: `service:order-service`, `env:demo` (not production `api-gateway`).
2. Pull recent errors and `@error.kind` facet.
3. If `DatabaseSchemaMismatch` → GitHub `stackgen-demo/order-service` `cmd/initdb/main.go`.
4. If `dependency` / `timeout` → APM child on `payment-service`; check pods and gRPC.
5. Check `aiden-chaos-monkey` logs for correlated `chaos_fault` in the same window.

### When a leaf service fires

1. Identify whether chaos used **isolated** mode vs **checkout_saga**.
2. For catalog/ad → check env fault modes and product/context in request.
3. For payment → card payload and `PAYMENT_DEMO_FAULT`.
4. Walk **up** the trace to `order-service` parent if present.

### Before recommending code changes

1. Scale chaos monkey to 0 if isolating app behavior.
2. Run Discovery in SRE app so topology matches this graph.
3. Mute unrelated monitors sharing the same webhook (wrong service tag → wrong repo in closed-loop PR).

---

## Pause and operations

**Stop random faults (keep apps running):**

```bash
kubectl -n aiden-demo scale deployment/aiden-chaos-monkey --replicas=0
```

**Stop agent billing:**

```bash
kubectl -n aiden-demo scale deployment/datadog-agent --replicas=0
```

**Fault profile (order-service repo):**

```bash
./scripts/set-fault-level.sh quiet|normal|noisy|demo|pr-demo|pr-payment-bug
./scripts/reload-fault-profile.sh
```

For **more Datadog alerts** during SRE app soak tests, use **`noisy`** or **`demo`**. Use **`pr-demo`** before closed-loop PR demos (chaos off). Revert to `normal` after the soak.

**Full stack deploy:**

```bash
./scripts/apply-datadog-secret.sh
./scripts/deploy-aiden-demo-stack.sh
./scripts/apply-datadog-monitors.sh   # [aiden-demo] prefix only
```

---

## Validation checklist

1. Deployments: order, payment, catalog, ad, datadog-agent, chaos-monkey — all `READY 1/1`.
2. Within one `CHAOS_MAX_INTERVAL_SEC` window, errors from **≥2 services** possible.
3. Each service has distinct `@error.kind` values in logs.
4. APM service map shows order → three dependencies.
5. Healthy checkout trace has **≥4 spans** and shared `trace_id` in logs.
6. Suspending monkey stops new error spikes.

---

## Related artifacts

| Artifact | Location |
|----------|----------|
| PoC workshop runbook | `examples/scenarios/datadog-aws-rca/POC-DEMO-RUNBOOK.md` |
| Scenario Terraform | `examples/scenarios/datadog-aws-rca/` |
| Prior incidents seed | `scripts/data/aiden-demo-incidents.jsonl` |
| Runbook sync (notebook → Guild) | [stackgen-sre-app `docs/runbook-sync.md`](https://github.com/appcd-dev/guild-apps/stackgen-sre-app/blob/main/docs/runbook-sync.md) |
| Stack source | [stackgen-demo/order-service](https://github.com/stackgen-demo/order-service) |
