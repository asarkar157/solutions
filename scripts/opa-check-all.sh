#!/usr/bin/env bash
# Run opa check on each .rego file (policies are standalone sg_policy artifacts, not one bundle).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! find . -name '*.rego' -not -path './.git/*' -print -quit 2>/dev/null | grep -q .; then
  echo "No .rego files found."
  exit 0
fi

failed=0
while IFS= read -r f; do
  [[ -z "${f}" ]] && continue
  echo "==> opa check: ${f}"
  if opa check --v1-compatible "${f}"; then
    :
  else
    failed=1
  fi
done < <(find . -name '*.rego' -not -path './.git/*' | sort)

exit "${failed}"
