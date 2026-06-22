# Incident Triage PoC — category taxonomy

> **Internal dry-run (2026-06-19)** — machine-exported RCAs from localhost synthetic cycle. **Human `human_*` scores still required** before customer-facing verdicts.

## How to produce the customer report

1. Run `./scripts/poc-eval/run-poc-cycle.sh all` (stackgen-sre-app) on customer JSONL
2. Merge human scores into `scored-*.csv` (`merge-scorecard.sh`)
3. Aggregate: `./aggregate-scores.sh scored.csv` (this repo)
4. Replace tables below with human-scored aggregates

## Summary (internal synthetic — eval v1 baseline)

| Metric | Value |
| ------ | ----- |
| Eval run id | `synthetic-v1-baseline-20260619T024403Z` |
| Incident count | 5 (engineering synthetic) |
| Memory bootstrap before this pass? | **no** |
| Machine RCA present rate | **100%** (5/5 after trace backfill) |
| p50 duration (all modes) | **178s** (offline sandbox; not 2-min SLA) |
| Human avg correctness | _pending review_ |

## Summary (internal synthetic — eval v2 post-memory)

| Metric | Value |
| ------ | ----- |
| Eval run id | `synthetic-v2-post-memory-20260619T024403Z` |
| Incident count | 5 |
| Memory bootstrap before this pass? | **yes** (`bootstrap-memory.sh` on synthetic.jsonl) |
| Machine RCA present rate | **100%** |
| p50 duration | **140s** (−38s vs v1 p50) |
| `prior_incidents_count` in CSV | **0** (trace API does not expose match counts — see blind spot) |
| Human avg correctness | _pending review_ |

## Machine duration by category (v1 → v2)

| Category | v1 duration (s) | v2 duration (s) | Machine RCA theme (v2) |
| -------- | --------------- | --------------- | ---------------------- |
| capacity | 144.8 | 214.5 | Alert/telemetry scope mismatch (not node eviction) |
| deploy | 194.5 | **90.5** | Unconfirmed deploy regression; missing rule UID / logs |
| dependency | 323.1 | **162.3** | Pool exhaustion (partial vs golden postgres analytics) |
| config | 157.3 | 160.7 | Stale scrape target / missing exporter |
| network | 178.4 | 140.2 | Alert metadata drift (not TGW route) |

**Artifacts:** `stackgen-sre-app/scripts/poc-eval/results/eval-raw-synthetic-v1-baseline-20260619T024403Z-filled.csv` and `…v2-post-memory…-filled.csv`

## Summary (opsverse live — eval v1 on ai.dev)

| Metric | Value |
| ------ | ----- |
| Eval run id | `live-ai-dev-20260619T181600Z` |
| Incident count | 17 (opsverse-demo Grafana live replay) |
| Memory bootstrap before this pass? | **no** |
| Machine RCA present rate | **100%** (17/17) |
| p50 duration (live) | **103s** (capacity); **124s** (unknown) |
| Human avg correctness | **0.84** (trace-informed draft scorecard) |
| Human avg completeness | **0.78** |
| Human avg actionability | **0.79** |
| Latency pass rate (≤120s) | **53%** (9/17) |
| Binary pass (correctness > 0.4) | **94%** (16/17) |

**Artifacts:** `stackgen-sre-app/scripts/poc-eval/results/scored-live-ai-dev-20260619T181600Z.csv`, `aggregate-live-ai-dev-20260619T181600Z.csv`

**Weakest row:** `POC-kubernetespodnothealthy-tech-store-payment-service` (correctness **0.35**) — node/kubelet hypothesis vs golden app process termination; `k8s_connected=false` on ai.dev at investigate time.

## Summary (opsverse live — eval v2 focus on ai.dev)

| Metric | Value |
| ------ | ----- |
| Eval run id | `live-ai-dev-v2-20260619T184808Z` |
| Incident count | 3 (payment PodNotHealthy, kafka SS mismatch, zookeeper PodNotHealthy) |
| Human avg correctness | **0.86** (trace-informed draft) |
| Latency pass rate (≤120s) | **0%** (153s avg; thorough metrics path) |

**Artifacts:** `stackgen-sre-app/scripts/poc-eval/results/scored-live-ai-dev-v2-20260619T184808Z.csv`

### v1 → v2 lift (focus rows)

| Incident | v1 correctness | v2 correctness | v2 mechanism vs v1 |
| -------- | -------------- | -------------- | ------------------ |
| kafka SS ReplicasMismatch | 0.57 (DNS) | **0.88** (ImagePullBackOff) | ErrImagePull on kafka-0 before DNS narrative |
| zookeeper PodNotHealthy | 0.65 (hedged) | **0.92** (bitnami tag) | Concrete missing image tag |
| payment PodNotHealthy | 0.35 (node/kubelet) | **0.78** (SIGTERM/npm Error) | App process termination vs infra guess |

**Infra applied before v2:** `sre-boost` with `enable_ubuntu_kubectl=true` on ai.dev agent; deploy branch `ENG-3250-rca-storm-poc-improvements` pushed (storm prompt + skills + trace gates — pending SRE app redeploy on ai.dev).

## Category matrix (human scores — opsverse live v1)

Threshold guidance: **reliable OOTB** ≥ 0.75 avg human correctness; **weak** 0.50–0.74; **non-triagable OOTB** < 0.50.

| Category | Count | Avg correctness | Avg completeness | Avg actionability | Latency pass rate | OOTB verdict | Notes |
| -------- | ----- | --------------- | ---------------- | ----------------- | ----------------- | ------------ | ----- |
| capacity | 8 | 0.74 | 0.73 | 0.80 | 0.62 | **weak** | payment-service miss; kafka SS mismatch DNS vs ImagePull |
| deploy | 1 | 0.95 | 0.85 | 0.90 | 1.00 | **reliable** | APM 5XX exceeds provisional golden (MySQL AMOUNT) |
| dependency | 2 | 1.00 | 0.85 | 0.90 | 0.00 | **reliable** | postgres exporter localhost target; slow (>120s) |
| unknown | 6 | 0.95 | 0.81 | 0.73 | 0.50 | **reliable** | URL/blackbox, redis, pod capacity |

## Category matrix (human scores — synthetic dry-run)

Threshold guidance: **reliable OOTB** ≥ 0.75 avg human correctness; **weak** 0.50–0.74; **non-triagable OOTB** < 0.50.

| Category | Count | Avg correctness | Avg completeness | Latency pass rate | OOTB verdict | Notes |
| -------- | ----- | --------------- | ---------------- | ----------------- | ------------ | ----- |
| capacity | 1 | | | | _pending_ | v2 machine RCA ≠ golden eviction narrative |
| deploy | 1 | | | | _pending_ | |
| dependency | 1 | | | | _pending_ | |
| config | 1 | | | | _pending_ | |
| network | 1 | | | | _pending_ | live_replay mode but offline prompt path |

## Integration gaps

| Integration | Incidents affected | Mitigation |
| ----------- | ------------------ | ---------- |
| **Kubernetes (live cluster)** | payment-service PodNotHealthy, zookeeper hedge | Wire k8s/ubuntu integration on ai.dev (`examples/scenarios/sre-boost`); verify `k8s_connected=true` |
| **Storm sibling context in investigate prompt** | kafka SS ReplicasMismatch | Deploy PR #208 `stormContextForInvestigation` |
| Live Grafana series for synthetic labels | SYN-001..005 offline | Use `run-live.sh` on customer stack for competitive scores |
| AWS (network) | SYN-005 golden | Wire `aios-integration-aws` for TGW-style incidents |
| GitHub (deploy correlation) | SYN-002 golden | Wire GitHub integration + change-correlation spawn |

## Memory lift (req 7) — provisional

Bootstrap ran; **no measurable lift in `prior_incidents_count`** on this pass. Likely causes:

1. Bootstrap agent chats may not have finished `memory_store` before v2 started (20s/row wait).
2. Trace export does not surface `prior_incidents.match_count` (schema stubs only).
3. Offline prompts lack live alert fingerprints for memory similarity.

**Next:** verify Memory Explorer for `shared:incidents` imports; increase bootstrap wait; score human correctness on SYN-001 after memory (expect lift on capacity row).

## Phase 4 (plan) — not started

- Live webhook + SRE UI investigate demo on customer Grafana
- Customer JSONL (15–25 incidents)
- Procurement PDF from `scripts/render-scorecard.md` after human scores
