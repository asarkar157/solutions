#!/usr/bin/env bash
# Project-detect validation + optional gh pr checks polling with backoff.
set -euo pipefail

REPO_DIR="${1:?repo_dir}"
PR_NUMBER="${2:-}"
MAX_RETRIES="${MAX_RETRIES:-30}"
RETRY_INTERVAL_SECONDS="${RETRY_INTERVAL_SECONDS:-30}"

cd "$REPO_DIR"

quality_summary="PASS"
fmt_exit=0

if [ -f package.json ]; then
  if jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
    npm run lint --if-present 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="NEEDS_REVISION"
  fi
  if [ "$quality_summary" = "PASS" ] && jq -e '.scripts.test' package.json >/dev/null 2>&1; then
    npm test --if-present 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="NEEDS_REVISION"
  fi
elif [ -f go.mod ]; then
  go test ./... 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="NEEDS_REVISION"
elif [ -f Cargo.toml ]; then
  cargo test 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="NEEDS_REVISION"
elif [ -f pyproject.toml ] || [ -f setup.py ]; then
  if command -v pytest >/dev/null 2>&1; then
    pytest -q 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="NEEDS_REVISION"
  fi
elif find . -maxdepth 3 -name '*.tf' -print -quit | grep -q .; then
  if command -v terraform >/dev/null 2>&1; then
    terraform fmt -check -recursive . 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="NEEDS_REVISION"
    terraform init -backend=false -input=false >/dev/null 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="BLOCKED"
    if [ "$quality_summary" = "PASS" ]; then
      terraform validate 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="NEEDS_REVISION"
    fi
  elif command -v tofu >/dev/null 2>&1; then
    tofu fmt -check -recursive . 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="NEEDS_REVISION"
    tofu init -backend=false -input=false >/dev/null 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="BLOCKED"
    if [ "$quality_summary" = "PASS" ]; then
      tofu validate 2>"$REPO_DIR/.specsym-validate.err" || quality_summary="NEEDS_REVISION"
    fi
  fi
fi

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "${PACK_DIR}/ci-spec-linkage.sh" ] && [ "$quality_summary" = "PASS" ]; then
  if ! "${PACK_DIR}/ci-spec-linkage.sh" "$REPO_DIR" 2>"$REPO_DIR/.specsym-validate.err"; then
    quality_summary="NEEDS_REVISION"
  fi
fi

ci_status="SKIPPED"
if [ -n "$PR_NUMBER" ] && command -v gh >/dev/null 2>&1; then
  ci_status="PENDING"
  local_interval="$RETRY_INTERVAL_SECONDS"
  for ((i = 1; i <= MAX_RETRIES; i++)); do
    checks_json="$(gh pr checks "$PR_NUMBER" --json name,state,bucket 2>/dev/null || echo "[]")"
    if [ "$checks_json" = "[]" ] || [ "$checks_json" = "FAILED" ]; then
      sleep "$local_interval"
      local_interval=$((local_interval * 2))
      [ "$local_interval" -gt 300 ] && local_interval=300
      continue
    fi
    pending="$(printf '%s' "$checks_json" | jq '[.[] | select(.state == "pending" or .state == "running" or .bucket == "pending")] | length')"
    failed="$(printf '%s' "$checks_json" | jq '[.[] | select(.state == "fail" or .state == "failure" or .state == "error")] | length')"
    if [ "${failed:-0}" -gt 0 ]; then
      ci_status="FAILED"
      quality_summary="NEEDS_REVISION"
      break
    fi
    if [ "${pending:-0}" -eq 0 ]; then
      ci_status="PASS"
      break
    fi
    sleep "$local_interval"
    local_interval=$((local_interval * 2))
    [ "$local_interval" -gt 300 ] && local_interval=300
  done
  [ "$ci_status" = "PENDING" ] && ci_status="TIMEOUT"
fi

echo "fmt_exit=$fmt_exit"
echo "quality_summary=$quality_summary"
echo "module_quality_summary=$quality_summary"
echo "ci_status=$ci_status"
echo "stage_summary:validate-and-test=$quality_summary"
