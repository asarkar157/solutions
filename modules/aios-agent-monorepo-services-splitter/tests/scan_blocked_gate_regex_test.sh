#!/usr/bin/env bash
# Regression: scan-blocked-gate must not fire on architect prose quoting sentinel names.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"

ROOT="${ROOT}" MAIN="${MAIN}" python3 << 'PY'
import pathlib
import re
import sys

main = pathlib.Path(__import__("os").environ["MAIN"]).read_text()
m = re.search(r'scan_blocked_gate_match_regex\s*=\s*"([^"]+)"', main)
if not m:
    print("FAIL: scan_blocked_gate_match_regex local not found in main.tf", file=sys.stderr)
    sys.exit(1)
pat = m.group(1)

# Successful clone summary from execution aaa54a9f (resilience4j) — gate must NOT match.
ok_output = """---
## `clone-and-boundary-scan` — Stage Complete ✅

**`stage_summary:clone-and-boundary-scan=ok`**

### Sentinel Check
- ✅ No `71WORK_ROOT` / `79WORK_ROOT` dollar-escape corruption detected
- ✅ No `clone_blocker=wrong_shell_dollar_escape`
- ✅ No `blocked:clone_failed` or `blocked:boundary_scan_failed`
- ✅ Script pack `20260602.9` decoded and executed successfully

| `boundary_scan_json_attached` | `true` |
"""

if re.search(pat, ok_output):
    print("FAIL: scan-blocked-gate regex matches successful clone stage output", file=sys.stderr)
    sys.exit(1)

fail_samples = [
    ("blocked:runner_failed", "blocked:runner_failed\n"),
    ("stage_summary blocked", "stage_summary:clone-and-boundary-scan=blocked\n"),
    ("clone_blocker", "clone_blocker=wrong_shell_dollar_escape\n"),
    ("script_pack_error", "script_pack_error=runner_sha256_mismatch\n"),
    ("runner_sha256_mismatch", "runner_sha256_mismatch on integration\n"),
    ("script_pack_mismatch", "script pack version mismatch\n"),
    ("work_root_error", "work_root_error=missing_workflow_run_id\n"),
    ("boundary_scan_json_attached=false", "boundary_scan_json_attached=false\n"),
]
for name, sample in fail_samples:
    if not re.search(pat, sample):
        print(f"FAIL: scan-blocked-gate regex must match emitted sentinel: {name}", file=sys.stderr)
        sys.exit(1)

print("OK: scan-blocked-gate regex rejects success prose and matches emitted sentinels")
PY
