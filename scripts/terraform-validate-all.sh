#!/usr/bin/env bash
# Run terraform init -backend=false and terraform validate in every directory
# under modules/ and examples/ that contains at least one .tf file.
# Same discovery logic as the "Terraform validate" job in .github/workflows/ci.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! find modules examples -type f -name '*.tf' -print -quit 2>/dev/null | grep -q .; then
  echo "No Terraform directories found under modules/ or examples/."
  exit 0
fi

failed=0
while IFS= read -r dir; do
  [[ -z "${dir}" ]] && continue
  echo "==> terraform validate: ${dir}"
  if (cd "${dir}" && terraform init -backend=false -input=false && terraform validate); then
    :
  else
    failed=1
  fi
done < <(find modules examples -type f -name '*.tf' 2>/dev/null | sed 's|/[^/]*$||' | sort -u)

exit "${failed}"
