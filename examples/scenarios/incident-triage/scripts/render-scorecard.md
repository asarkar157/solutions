# PoC scorecard leave-behind (procurement export)

Convert human-scored eval CSV into a customer-branded PDF or slide deck. This is a **template** — replace placeholders after eval v1/v2.

## Inputs

| File | Source |
| ---- | ------ |
| `scored.csv` | Merge `eval-raw-*.csv` + human rubric columns |
| `aggregate.csv` | `./aggregate-scores.sh scored.csv` |
| `incidents.jsonl` | Customer golden dataset |

## Executive summary (one slide)

**Headline:** StackGen Incident Triage PoC — measured on [Customer Name]'s [N] historical incidents

**Key numbers (fill from aggregate):**

- Baseline accuracy (human correctness avg): **__%**
- After curated memory bootstrap (v2): **__%** (+__ pp lift)
- Live replay p50 duration: **__ s** (Resolve public benchmark: 5 min)
- Categories reliable OOTB (≥75%): **list**

**Explain like I'm five:** We graded the copilot's homework against your published answer key — before and after we let it study your old postmortems.

## Slide 2 — Methodology

- Golden dataset: customer postmortems / published RCAs
- Single-prompt investigation (no back-and-forth with on-call)
- Human rubric: correctness, completeness, actionability
- Reproducible batch runner (`poc-eval/run.sh`) + versioned manifest

## Slide 3 — Category heatmap

Paste aggregate table:

```text
category | count | avg_correctness | latency_pass_rate
```

Color code: green ≥0.75, yellow 0.50–0.74, red <0.50

## Slide 4 — Before / after memory

| Phase | Avg correctness | Notes |
| ----- | --------------- | ----- |
| v1 baseline | | No shared memory |
| v2 post-bootstrap | | 10 curated RCAs in shared:incidents |

Screenshot: Guild Memory Explorer filtered to `shared:incidents` + one imported RCA.

## Slide 5 — Honest limits

Link or summarize [`docs/incident-triage-poc-limits.md`](../docs/incident-triage-poc-limits.md):

- Offline replay scores lower (no live metrics)
- Weak OOTB categories and required integrations
- Memory is pull-based with score gates — not black-box learning

## Slide 6 — Why StackGen vs Resolve / PlayerZero

| Dimension | Resolve / PlayerZero | StackGen PoC |
| --------- | -------------------- | ------------ |
| Accuracy proof | Anecdotal / vendor stats | **Your** golden scorecard |
| Tuning | Opaque | Git-versioned skills + Terraform |
| Learning loop | Claimed continuous | **Measured** v1 → v2 lift |
| SRE-native | Resolve: broad; PZ: code/ticket | Grafana alert → evidence RCA |

## Export commands

```bash
# Aggregate for slides
./aggregate-scores.sh results/scored.csv > results/aggregate.csv

# Optional: CSV → markdown table for Pandoc PDF
column -t -s, results/aggregate.csv > results/aggregate-table.txt
pandoc results/scorecard-brief.md -o StackGen-PoC-Scorecard.pdf
```

Create `scorecard-brief.md` by copying this template sections with filled numbers.

## Appendix — incident-level table (optional)

Include 5 representative rows: `incident_id`, `category`, `golden_root_cause` (truncated), `root_cause` (generated), `human_correctness`, `trace_url`.

Do **not** export full prompts or tokens in customer leave-behind.
