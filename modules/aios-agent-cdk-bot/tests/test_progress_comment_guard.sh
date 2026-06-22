#!/usr/bin/env bash
# Static checks for progress-comment embedded script and spawn contract.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/scripts/progress-comment.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: missing progress comment script" >&2
  exit 1
fi

if ! grep -q 'progress_comment_id=' "$SCRIPT"; then
  echo "FAIL: template must emit progress_comment_id=" >&2
  exit 1
fi

if ! grep -q 'gh api -X PATCH' "$SCRIPT"; then
  echo "FAIL: script must PATCH existing comments" >&2
  exit 1
fi

if ! grep -q 'gh api -X POST' "$SCRIPT"; then
  echo "FAIL: script must POST initial comment" >&2
  exit 1
fi

echo "OK: progress comment guard checks passed"
