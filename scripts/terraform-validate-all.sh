#!/usr/bin/env bash
# Run init -backend=false and validate in every directory under modules/ and examples/
# that contains at least one .tf file.
# Prefers OpenTofu (`tofu`); falls back to HashiCorp Terraform (`terraform`) — same flags.
# Same discovery logic as the OpenTofu validate job in .github/workflows/ci.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if command -v tofu >/dev/null 2>&1; then
  TF_BIN=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF_BIN=terraform
else
  echo "error: neither 'tofu' (OpenTofu) nor 'terraform' found in PATH" >&2
  exit 1
fi
echo "Using ${TF_BIN} (install OpenTofu for the default; HashiCorp Terraform is interchangeable)"

if ! find modules examples -type f -name '*.tf' -print -quit 2>/dev/null | grep -q .; then
  echo "No Terraform directories found under modules/ or examples/."
  exit 0
fi

failed=0
while IFS= read -r dir; do
  [[ -z "${dir}" ]] && continue
  echo "==> ${TF_BIN} validate: ${dir}"
  # -upgrade: lock files may pin an older provider than required_providers allows; refresh for validate-only runs.
  if (cd "${dir}" && "${TF_BIN}" init -backend=false -input=false -upgrade && "${TF_BIN}" validate); then
    :
  else
    failed=1
  fi
done < <(find modules examples -type f -name '*.tf' 2>/dev/null | sed 's|/[^/]*$||' | sort -u)

exit "${failed}"
