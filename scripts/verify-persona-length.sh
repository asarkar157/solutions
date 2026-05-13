#!/usr/bin/env bash
# Hard rule: every agent persona file must be <= PERSONA_MAX_BYTES (default 15000).
#
# The Guild server rejects any agent register/update whose persona exceeds 15000
# bytes (see internal/guild/agentrouter/config.go: `len(c.Persona) > 15000`).
# Apply-time failures cascade: terraform marks the resource tainted and the next
# plan re-runs the same broken update. Catching it pre-merge is the only stable
# fix.
#
# This script walks every `modules/aios-agent-*/personas/**/*.md` file and exits
# non-zero if any exceeds the cap. It is wired into `make check` (and therefore
# CI) so violations block merges before the resource ever hits Guild.
#
# Override the cap by exporting PERSONA_MAX_BYTES; the default tracks Guild's
# current limit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LIMIT="${PERSONA_MAX_BYTES:-15000}"

# Discover persona files under any agent module's personas/ directory. We use
# find rather than a glob expansion so deeply-nested personas (e.g. one-off
# variants under personas/<role>/<scenario>.md) are caught too.
mapfile -t files < <(find modules -type d -name personas -prune -exec find {} -type f -name '*.md' \; 2>/dev/null | sort)

if (( ${#files[@]} == 0 )); then
  echo "verify-persona-length: no persona files found under modules/*/personas/"
  exit 0
fi

failed=0
echo "verify-persona-length: limit=${LIMIT} bytes; scanning ${#files[@]} persona file(s)"
for f in "${files[@]}"; do
  # `wc -c` reports bytes on every supported platform, matching Go's len()
  # semantics that Guild uses server-side.
  bytes=$(wc -c < "$f" | tr -d ' ')
  if (( bytes > LIMIT )); then
    over=$(( bytes - LIMIT ))
    printf "  ✗ %s — %d bytes (over by %d)\n" "$f" "$bytes" "$over"
    failed=1
  fi
done

if (( failed != 0 )); then
  echo ""
  echo "ERROR: one or more persona files exceed the ${LIMIT}-byte cap."
  echo "Guild rejects registers/updates with 'agent persona must be <= ${LIMIT} characters'."
  echo "Trim the offending files before merging."
  exit 1
fi

echo "verify-persona-length: all persona files within the ${LIMIT}-byte cap."
