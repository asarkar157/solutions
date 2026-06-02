#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANITIZE="${ROOT}/scripts/text-sanitize.sh"
chmod +x "$SANITIZE"

out="$(printf 'token [HIDDEN:abc123] ok\n' | bash "$SANITIZE")"
if grep -q 'HIDDEN' <<<"$out"; then
  echo "FAIL: expected HIDDEN token stripped" >&2
  exit 1
fi

echo "OK: text-sanitize tests passed"
