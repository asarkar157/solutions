#!/usr/bin/env bash
# aggregate-scores.sh — roll up human-scored eval CSV by category.
set -euo pipefail

usage() {
  echo "Usage: aggregate-scores.sh scored.csv"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

CSV="$1"
if [[ ! -f "$CSV" ]]; then
  echo "file not found: $CSV" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

python3 - "$CSV" <<'PY'
import csv
import sys
from collections import defaultdict

path = sys.argv[1]
with open(path, newline="", encoding="utf-8") as fh:
    rows = list(csv.DictReader(fh))

if not rows:
    print("no rows")
    sys.exit(1)

numeric = ("human_correctness", "human_completeness", "human_actionability")
groups = defaultdict(list)

for row in rows:
    cat = (row.get("category") or "unknown").strip() or "unknown"
    groups[cat].append(row)

print("category,count,avg_correctness,avg_completeness,avg_actionability,latency_pass_rate,avg_duration_s")

for cat in sorted(groups):
    items = groups[cat]
    n = len(items)

    def avg(field):
        vals = []
        for it in items:
            v = (it.get(field) or "").strip()
            if not v:
                continue
            try:
                vals.append(float(v))
            except ValueError:
                pass
        return sum(vals) / len(vals) if vals else None

    lat_ok = 0
    lat_n = 0
    dur_vals = []
    for it in items:
        lp = (it.get("human_latency_pass") or "").strip().lower()
        if lp in ("1", "true", "yes", "y"):
            lat_ok += 1
            lat_n += 1
        elif lp in ("0", "false", "no", "n"):
            lat_n += 1
        d = (it.get("duration_s") or "").strip()
        if d:
            try:
                dur_vals.append(float(d))
            except ValueError:
                pass

    lat_rate = f"{lat_ok / lat_n:.2f}" if lat_n else ""
    avg_dur = f"{sum(dur_vals) / len(dur_vals):.1f}" if dur_vals else ""

    def fmt(v):
        return f"{v:.3f}" if v is not None else ""

    print(
        f"{cat},{n},"
        f"{fmt(avg('human_correctness'))},"
        f"{fmt(avg('human_completeness'))},"
        f"{fmt(avg('human_actionability'))},"
        f"{lat_rate},"
        f"{avg_dur}"
    )
PY
