#!/usr/bin/env bash
# Integration smoke tests for spec-symphony scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOCK="$(mktemp -d)"
trap 'rm -rf "${MOCK}"' EXIT

export SPECSYM_PACK_DIR="${ROOT}"
export SPECSYM_ALLOW_DIRECT=1
export SDD_FRAMEWORK=openspec
export CHANGE_TYPE=brownfield

cd "${MOCK}"
git init -q
git config user.email "test@specsym.local"
git config user.name "SpecSym Test"

"${ROOT}/scripts/spec-bootstrap.sh" "${MOCK}"

if [ ! -f SPEC_SYMPHONY.md ]; then
  echo "FAIL: spec-bootstrap did not seed SPEC_SYMPHONY.md" >&2
  exit 1
fi

mkdir -p src
echo 'export const x = 1;' > src/index.ts
git add src/index.ts
git commit -q -m "feat: add index"

if "${ROOT}/scripts/ci-spec-linkage.sh" "${MOCK}" 2>/dev/null; then
  echo "FAIL: ci-spec-linkage should block code-only commit" >&2
  exit 1
fi

mkdir -p openspec/changes/CORE-1
echo '# change' > openspec/changes/CORE-1/proposal.md
git add openspec/changes/CORE-1/proposal.md
git commit -q -m "docs: spec"

if ! "${ROOT}/scripts/ci-spec-linkage.sh" "${MOCK}"; then
  echo "FAIL: ci-spec-linkage should pass with spec change" >&2
  exit 1
fi

echo "OK: spec-symphony script integration tests passed"
