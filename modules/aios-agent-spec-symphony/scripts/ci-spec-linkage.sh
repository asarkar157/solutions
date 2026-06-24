#!/usr/bin/env bash
# Verify code changes are accompanied by specification updates.
set -euo pipefail

TARGET_BRANCH="${TARGET_BRANCH:-origin/main}"
REPO_DIR="${1:-.}"

cd "$REPO_DIR"
git fetch origin main --quiet 2>/dev/null || true

CHANGED_FILES="$(git diff --name-only "${TARGET_BRANCH}"...HEAD 2>/dev/null || git diff --name-only HEAD~1 HEAD 2>/dev/null || true)"

if [ -z "${CHANGED_FILES}" ]; then
  CHANGED_FILES="$(git show --name-only --pretty=format: HEAD 2>/dev/null || true)"
fi

HAS_CODE_CHANGES=false
HAS_SPEC_CHANGES=false

while IFS= read -r file; do
  [ -z "${file}" ] && continue
  if [[ "${file}" =~ ^(src|lib|app|modules|pkg|internal)/.*\.(ts|js|tsx|jsx|py|rs|go|cs|java)$ ]]; then
    HAS_CODE_CHANGES=true
  fi
  if [[ "${file}" =~ ^(\.specify/|specs/|openspec/changes/|openspec/specs/|aidlc-docs/).*\.md$ ]]; then
    HAS_SPEC_CHANGES=true
  fi
done <<<"${CHANGED_FILES}"

if [ "$HAS_CODE_CHANGES" = true ] && [ "$HAS_SPEC_CHANGES" = false ]; then
  echo "spec_linkage_error=code_without_spec"
  echo "hint=update specs under .specify/, specs/, openspec/changes/, or aidlc-docs/"
  exit 1
fi

echo "spec_linkage=ok"
exit 0
