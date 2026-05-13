#!/usr/bin/env bash
# Hard rules for agent persona files:
#
#   1. Every `modules/aios-agent-*/personas/**/*.md` must be <= PERSONA_MAX_BYTES
#      (default 15000) bytes. The Guild server rejects any agent register/update
#      whose persona exceeds 15000 bytes (see internal/guild/agentrouter/
#      config.go: `len(c.Persona) > 15000`); apply-time failures cascade and the
#      resource gets stuck tainted. Catching it pre-merge is the only stable fix.
#
#   2. Every agent module that wires `persona = file(...)` in its main.tf must
#      ship a sibling `_persona_guard.tf` so the per-module `terraform_data`
#      precondition fires at plan time. Without this, a new module could ship
#      with no plan-time guard and only the CI script would catch it — adding
#      the guard file is a 10-line copy from any existing aios-agent-* module.
#
# Both checks run in one pass so `make check` / the CI persona-length job is the
# single hard rule for this concern.
#
# Override the byte cap via PERSONA_MAX_BYTES; the default tracks Guild's
# current limit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LIMIT="${PERSONA_MAX_BYTES:-15000}"

# ---------------------------------------------------------------------------
# Check 1 — byte cap on every persona file
# ---------------------------------------------------------------------------

# Discover persona files under any agent module's personas/ directory. We use
# find rather than a glob expansion so deeply-nested personas (e.g. one-off
# variants under personas/<role>/<scenario>.md) are caught too.
mapfile -t files < <(find modules -type d -name personas -prune -exec find {} -type f -name '*.md' \; 2>/dev/null | sort)

length_failed=0
if (( ${#files[@]} == 0 )); then
  echo "verify-persona-length: no persona files found under modules/*/personas/"
else
  echo "verify-persona-length: limit=${LIMIT} bytes; scanning ${#files[@]} persona file(s)"
  for f in "${files[@]}"; do
    # `wc -c` reports bytes on every supported platform, matching Go's len()
    # semantics that Guild uses server-side.
    bytes=$(wc -c < "$f" | tr -d ' ')
    if (( bytes > LIMIT )); then
      over=$(( bytes - LIMIT ))
      printf "  ✗ %s — %d bytes (over by %d)\n" "$f" "$bytes" "$over"
      length_failed=1
    fi
  done
fi

# ---------------------------------------------------------------------------
# Check 2 — every module with `persona = file(...)` ships _persona_guard.tf
# ---------------------------------------------------------------------------

# grep -l with a recursive glob across agent modules' top-level Terraform files.
# We deliberately do not recurse into nested module sub-paths — agent modules
# are flat by repo convention.
mapfile -t main_tfs < <(grep -lE 'persona[[:space:]]*=[[:space:]]*file' modules/aios-agent-*/main.tf 2>/dev/null | sort)

guard_failed=0
if (( ${#main_tfs[@]} > 0 )); then
  echo "verify-persona-length: checking ${#main_tfs[@]} agent module(s) for _persona_guard.tf"
  for main_tf in "${main_tfs[@]}"; do
    module_dir="$(dirname "$main_tf")"
    guard="$module_dir/_persona_guard.tf"
    if [[ ! -f "$guard" ]]; then
      printf "  ✗ %s missing — copy from any other aios-agent-*/_persona_guard.tf\n" "$guard"
      guard_failed=1
      continue
    fi
    # Sanity: the guard must wire fileset() against this module's personas/.
    # Catches a guard file that was copied but mangled (e.g. wrong path, removed
    # precondition). Match is intentionally loose; the canonical template lives
    # in the existing modules so drift here means real misuse, not a typo.
    if ! grep -q 'fileset("\${path.module}/personas"' "$guard"; then
      printf "  ✗ %s present but missing fileset(\"\${path.module}/personas\", ...) — refresh from template\n" "$guard"
      guard_failed=1
    fi
    if ! grep -q 'precondition' "$guard"; then
      printf "  ✗ %s present but has no precondition block — refresh from template\n" "$guard"
      guard_failed=1
    fi
  done
fi

# ---------------------------------------------------------------------------
# Aggregate exit
# ---------------------------------------------------------------------------

if (( length_failed != 0 )); then
  echo ""
  echo "ERROR: one or more persona files exceed the ${LIMIT}-byte cap."
  echo "Guild rejects registers/updates with 'agent persona must be <= ${LIMIT} characters'."
  echo "Trim the offending files before merging."
fi

if (( guard_failed != 0 )); then
  echo ""
  echo "ERROR: one or more agent modules are missing or have a broken _persona_guard.tf."
  echo "The per-module guard converts Guild's runtime 500 into a plan-time failure."
  echo "Copy modules/aios-agent-sdlc/_persona_guard.tf (or any other agent module's copy) into the offending module."
fi

if (( length_failed != 0 || guard_failed != 0 )); then
  exit 1
fi

echo "verify-persona-length: byte cap OK; _persona_guard.tf present in every agent module."
