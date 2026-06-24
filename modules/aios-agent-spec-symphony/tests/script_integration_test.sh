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

# --- AI-DLC framework smoke ---
AIDLC_MOCK="$(mktemp -d)"
trap 'rm -rf "${MOCK}" "${AIDLC_MOCK}"' EXIT

export SDD_FRAMEWORK=ai-dlc
export CHANGE_TYPE=brownfield
export FEATURE_ID=CORE-99
export ISSUE_TITLE="AI-DLC feature"
export ISSUE_BODY="Test ticket body"

"${ROOT}/scripts/fetch-aidlc-rules.sh" "1.0.0" "${ROOT}/.generated/aidlc-rules"

cd "${AIDLC_MOCK}"
git init -q
git config user.email "test@specsym.local"
git config user.name "SpecSym Test"

"${ROOT}/scripts/spec-bootstrap.sh" "${AIDLC_MOCK}"

if [ ! -d .aidlc-rule-details/common ]; then
  echo "FAIL: ai-dlc bootstrap did not seed .aidlc-rule-details/" >&2
  exit 1
fi

if [ ! -f AGENTS.md ] && [ ! -f .cursor/rules/ai-dlc-workflow.mdc ]; then
  echo "FAIL: ai-dlc bootstrap did not seed AGENTS.md or .cursor/rules/ai-dlc-workflow.mdc" >&2
  exit 1
fi

"${ROOT}/scripts/author-spec.sh" "${AIDLC_MOCK}"

if [ ! -f aidlc-docs/CORE-99/construction.md ]; then
  echo "FAIL: author-spec did not create aidlc-docs/CORE-99/construction.md" >&2
  exit 1
fi

mkdir -p src
echo 'export const y = 2;' > src/feature.ts
git add src/feature.ts
git commit -q -m "feat: add feature"

if "${ROOT}/scripts/ci-spec-linkage.sh" "${AIDLC_MOCK}" 2>/dev/null; then
  echo "FAIL: ci-spec-linkage should block code-only commit for ai-dlc" >&2
  exit 1
fi

git add aidlc-docs/CORE-99/
git commit -q -m "docs: aidlc spec"

if ! "${ROOT}/scripts/ci-spec-linkage.sh" "${AIDLC_MOCK}"; then
  echo "FAIL: ci-spec-linkage should pass with aidlc-docs change" >&2
  exit 1
fi

echo "OK: ai-dlc framework integration tests passed"
