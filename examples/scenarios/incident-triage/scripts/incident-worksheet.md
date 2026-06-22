# Incident Triage PoC — SE worksheet

Use this worksheet with the customer to build `incidents.jsonl` (one JSON object per line). Each row powers batch eval (`poc-eval/run.sh`) and optional memory bootstrap (`bootstrap-memory.sh`).

## What to collect per incident

| Field | Where to find it | Notes |
|-------|------------------|-------|
| `id` | Ticket / postmortem id | Stable slug, e.g. `INC-2024-042` |
| `category` | Postmortem theme | `capacity`, `deploy`, `dependency`, `config`, `network`, `data`, or `unknown` |
| `mode` | Replay plan | `offline` if only narrative exists; `live_replay` if alert can be re-fired in Grafana |
| `initial_prompt` | Alert context at fire time | Run `build-prompt-from-row.sh` after filling labels + description |
| `golden_root_cause` | Published RCA — one sentence | Mechanism + failing component |
| `golden_mitigation` | Published action items | Verifiable steps (array of strings) |
| `golden_rca_full` | Full postmortem text | Used for human scorecard + memory bootstrap |
| `labels` | Alert labels | `service`, `namespace`, `cluster`, `alertname` |
| `integrations_required` | Stack used in RCA | e.g. `grafana`, `aws`, `github`, `k8s` |
| `ootb_expected` | SE pre-call guess | `pass`, `weak`, or `fail` — revise after eval v1 |
| `approved_by` | Reviewer email | Provenance for curated memory import |
| `source` | Link or ticket | e.g. `postmortem/INC-042`, `curated_import` |

## Extraction checklist (per incident)

1. Locate the **published RCA** or postmortem (Confluence, Slack archive, PagerDuty note).
2. Copy **root cause** as the customer wrote it — do not paraphrase for the golden field.
3. List **mitigation steps** the customer actually took (not hypothetical fixes).
4. Capture **alert identity** at fire time: title, severity, fingerprint/UID, labels, timestamp.
5. Mark **mode**: if Grafana/metrics no longer exist, use `offline` and expect lower automated scores.
6. Assign **category** for taxonomy rollup (see `docs/incident-triage-poc-taxonomy.md` after eval v1).

## Volume targets

| Phase | Count | Purpose |
|-------|-------|---------|
| Engineering dry-run | 5 | Use `data/synthetic.jsonl` |
| Customer eval v1 | 15–25 | Diverse categories |
| Memory bootstrap | 10+ | Rows with strong `golden_rca_full` for eval v2 lift demo |

## JSONL format

- UTF-8, one JSON object per line, no trailing comma.
- Validate: `jq -c . incidents.jsonl > /dev/null` for each line.
- Schema: [`incidents.schema.json`](./incidents.schema.json).

## Prompt generation

After filling structured fields (without `initial_prompt`):

```bash
./build-prompt-from-row.sh --row '{"id":"INC-001",...}' >> incidents.jsonl
```

Or generate prompt only:

```bash
./build-prompt-from-row.sh --row-file row.json --prompt-only
```

## Human scorecard (after batch run)

1. Run `poc-eval/run.sh` → `results/eval-raw-*.csv`
2. Merge with [`scorecard-template.csv`](./scorecard-template.csv) columns
3. Score correctness / completeness / actionability (0–1 or 1–5)
4. Aggregate: `./aggregate-scores.sh results/scored.csv`

## Memory bootstrap (eval v2)

After v1 baseline:

```bash
export GUILD_URL=... STACKGEN_TOKEN=... GUILD_PROJECT_ID=...
./bootstrap-memory.sh --dataset incidents.jsonl --mode agent
```

See [`bootstrap-memory.sh`](./bootstrap-memory.sh) and PoC runbook in [`../README.md`](../README.md).
