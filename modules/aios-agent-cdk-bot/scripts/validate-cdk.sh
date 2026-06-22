#!/usr/bin/env bash
# validate-cdk.sh — six-check CDK validation pipeline (lint, typecheck, synth, cfn-lint, test, nag).
# Args: work_root module_path
set -euo pipefail

work_root="${1:?WORK_ROOT}"
module_path="${2:?MODULE_PATH}"
work_dir="$work_root/.work"
mkdir -p "$work_dir"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ensure-cdk-toolchain.sh
source "${script_dir}/ensure-cdk-toolchain.sh"

mirror_note() {
  local key="${2:?KEY}"
  local value="${3:?VALUE}"
  local notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"
  jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$notes" >"${notes}.tmp" \
    && mv "${notes}.tmp" "$notes"
}

pass_or_fail() {
  if [ "$1" -eq 0 ]; then echo PASS; else echo FAIL; fi
}

if [ ! -d "$module_path" ]; then
  echo "validation_error=module_path_missing"
  echo "module_quality_summary=BLOCKED"
  exit 1
fi

# Resolve app root (module_path may be construct subdir)
app_root="$module_path"
if [ -f "$script_dir/detect-cdk-language.sh" ]; then
  # shellcheck disable=SC1090
  while IFS= read -r line; do
    case "$line" in
      cdk_app_root=*) app_root="${line#cdk_app_root=}" ;;
      cdk_language=*) cdk_language="${line#cdk_language=}" ;;
      test_runner=*) test_runner="${line#test_runner=}" ;;
    esac
  done < <("$script_dir/detect-cdk-language.sh" "$module_path")
fi

cdk_language="${cdk_language:-unknown}"
test_runner="${test_runner:-unknown}"
if [ -n "${app_root:-}" ] && [ -d "$app_root" ]; then
  cd "$app_root"
else
  cd "$module_path"
  app_root="$module_path"
fi

lint_rc=0 typecheck_rc=0 synth_rc=0 cfnlint_rc=0 test_rc=0 nag_rc=0 deps_rc=0

binary=""
if [ "$cdk_language" = "python" ]; then
  binary="$(python3 --version 2>&1 | head -1)"
elif [ "$cdk_language" = "typescript" ]; then
  ensure_cdk_toolchain || {
    echo "validation_error=node_install_failed"
    echo "module_quality_summary=BLOCKED"
    exit 1
  }
  binary="$(node --version 2>&1 | head -1)"
else
  binary="unknown-cdk-language"
  echo "validation_error=unknown_cdk_language"
  echo "module_quality_summary=BLOCKED"
  exit 1
fi

echo "validate_started=true"
echo "cdk_language=${cdk_language}"
echo "binary=${binary}"

if [ -x "$script_dir/bootstrap-deps.sh" ]; then
  set +e
  "$script_dir/bootstrap-deps.sh" "$app_root" "$cdk_language" >"$work_dir/deps.out" 2>&1
  deps_rc=$?
  set -e
  grep -E '^deps_exit=' "$work_dir/deps.out" || echo "deps_exit=${deps_rc}"
fi

init_rc=$deps_rc
fmt_rc=0

run_ts_lint() {
  if [ -f package.json ] && jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
    npm run lint >"$work_dir/lint.out" 2>&1 || lint_rc=$?
    return
  fi
  if command -v eslint >/dev/null 2>&1; then
    npx eslint . --max-warnings=0 >"$work_dir/lint.out" 2>&1 || lint_rc=$?
    return
  fi
  if command -v prettier >/dev/null 2>&1; then
    npx prettier --check . >"$work_dir/lint.out" 2>&1 || lint_rc=$?
    return
  fi
  echo "lint_skipped=no_linter" >"$work_dir/lint.out"
}

run_ts_typecheck() {
  if [ -f tsconfig.json ]; then
    if jq -e '.scripts.typecheck' package.json >/dev/null 2>&1; then
      npm run typecheck >"$work_dir/typecheck.out" 2>&1 || typecheck_rc=$?
      return
    fi
    npx tsc --noEmit >"$work_dir/typecheck.out" 2>&1 || typecheck_rc=$?
    return
  fi
  echo "typecheck_skipped=no_tsconfig" >"$work_dir/typecheck.out"
}

run_py_lint() {
  if [ -d .venv ]; then
    # shellcheck disable=SC1091
    . .venv/bin/activate
  fi
  if command -v ruff >/dev/null 2>&1; then
    ruff check . >"$work_dir/lint.out" 2>&1 || lint_rc=$?
  elif command -v flake8 >/dev/null 2>&1; then
    flake8 . >"$work_dir/lint.out" 2>&1 || lint_rc=$?
  else
    echo "lint_skipped=no_ruff" >"$work_dir/lint.out"
  fi
}

run_py_typecheck() {
  if [ -d .venv ]; then
    # shellcheck disable=SC1091
    . .venv/bin/activate
  fi
  if [ -f pyproject.toml ] && command -v mypy >/dev/null 2>&1; then
    mypy . >"$work_dir/typecheck.out" 2>&1 || typecheck_rc=$?
  elif [ -f pyrightconfig.json ] && command -v pyright >/dev/null 2>&1; then
    pyright >"$work_dir/typecheck.out" 2>&1 || typecheck_rc=$?
  else
    echo "typecheck_skipped=no_mypy" >"$work_dir/typecheck.out"
  fi
}

if [ "$cdk_language" = "typescript" ]; then
  run_ts_lint &
  lint_pid=$!
  run_ts_typecheck &
  typecheck_pid=$!
  wait "$lint_pid" || true
  wait "$typecheck_pid" || true
fi

if [ "$cdk_language" = "python" ]; then
  run_py_lint &
  lint_pid=$!
  run_py_typecheck &
  typecheck_pid=$!
  wait "$lint_pid" || true
  wait "$typecheck_pid" || true
fi

# Synth
if [ "$cdk_language" = "python" ] && [ -d .venv ]; then
  # shellcheck disable=SC1091
  . .venv/bin/activate
fi

if command -v cdk >/dev/null 2>&1; then
  cdk synth --no-staging >"$work_dir/cdk-synth.out" 2>&1 || synth_rc=$?
elif [ -f package.json ]; then
  npx cdk synth --no-staging >"$work_dir/cdk-synth.out" 2>&1 || synth_rc=$?
else
  synth_rc=1
  echo "synth_error=no_cdk_cli" >"$work_dir/cdk-synth.out"
fi

# Post-synth parallel: cfn-lint + tests
cfn_out_dir="cdk.out"
[ -d "$cfn_out_dir" ] || cfn_out_dir="."

run_cfn_lint() {
  if command -v cfn-lint >/dev/null 2>&1; then
    cfn-lint "$cfn_out_dir" >"$work_dir/cfn-lint.out" 2>&1 || cfnlint_rc=$?
  else
    echo "cfn_lint_skipped=not_installed" >"$work_dir/cfn-lint.out"
    cfnlint_rc=0
  fi
}

run_tests() {
  if [ "$cdk_language" = "typescript" ]; then
    if jq -e '.scripts.test' package.json >/dev/null 2>&1; then
      npm test -- --passWithNoTests=false >"$work_dir/test.out" 2>&1 || test_rc=$?
      return
    fi
    if [ "$test_runner" = "vitest" ]; then
      npx vitest run >"$work_dir/test.out" 2>&1 || test_rc=$?
      return
    fi
    npx jest --passWithNoTests=false >"$work_dir/test.out" 2>&1 || test_rc=$?
    return
  fi
  if [ "$cdk_language" = "python" ]; then
    if [ -d .venv ]; then
      # shellcheck disable=SC1091
      . .venv/bin/activate
    fi
    if [ -d tests ] || compgen -G "test_*.py" >/dev/null; then
      pytest -q >"$work_dir/test.out" 2>&1 || test_rc=$?
    else
      echo "test_skipped=no_tests" >"$work_dir/test.out"
      test_rc=1
    fi
  fi
}

run_nag() {
  if [ "$cdk_language" = "typescript" ]; then
    if compgen -G "**/*nag*.test.ts" >/dev/null || compgen -G "**/nag.test.ts" >/dev/null; then
      if jq -e '.scripts.test' package.json >/dev/null 2>&1; then
        npm test -- --testPathPattern=nag >"$work_dir/nag.out" 2>&1 || nag_rc=$?
        return
      fi
    fi
  fi
  if [ "$cdk_language" = "python" ] && [ -f tests/test_nag.py ]; then
    if [ -d .venv ]; then
      # shellcheck disable=SC1091
      . .venv/bin/activate
    fi
    pytest -q tests/test_nag.py >"$work_dir/nag.out" 2>&1 || nag_rc=$?
    return
  fi
  echo "nag_skipped=no_nag_test" >"$work_dir/nag.out"
  nag_rc=0
}

run_cfn_lint &
cfn_pid=$!
run_tests &
test_pid=$!
run_nag &
nag_pid=$!
wait "$cfn_pid" || true
wait "$test_pid" || true
wait "$nag_pid" || true

# Legacy sentinels for workflow gates (fmt=lint, validate=synth, init=deps)
fmt_rc=$lint_rc
valid_rc=$synth_rc

lint_result="$(pass_or_fail "$lint_rc")"
typecheck_result="$(pass_or_fail "$typecheck_rc")"
synth_result="$(pass_or_fail "$synth_rc")"
cfnlint_result="$(pass_or_fail "$cfnlint_rc")"
test_result="$(pass_or_fail "$test_rc")"
nag_result="$(pass_or_fail "$nag_rc")"

slug="$(printf '%s' "$module_path" | sed 's#^/##; s#/#_#g' | sed 's/[^a-zA-Z0-9._-]/_/g')"

mirror_note "$work_root" "quality_check_lint:${slug}" "$lint_result"
mirror_note "$work_root" "quality_check_typecheck:${slug}" "$typecheck_result"
mirror_note "$work_root" "quality_check_synth:${slug}" "$synth_result"
mirror_note "$work_root" "quality_check_cfn_lint:${slug}" "$cfnlint_result"
mirror_note "$work_root" "quality_check_test:${slug}" "$test_result"
mirror_note "$work_root" "quality_check_nag:${slug}" "$nag_result"
mirror_note "$work_root" "quality_check_lint" "$lint_result"
mirror_note "$work_root" "quality_check_typecheck" "$typecheck_result"
mirror_note "$work_root" "quality_check_synth" "$synth_result"
mirror_note "$work_root" "quality_check_cfn_lint" "$cfnlint_result"
mirror_note "$work_root" "quality_check_test" "$test_result"
mirror_note "$work_root" "quality_check_nag" "$nag_result"

summary="binary=${binary}; lint=${lint_result}; typecheck=${typecheck_result}; synth=${synth_result}; cfn_lint=${cfnlint_result}; test=${test_result}; nag=${nag_result}"
mirror_note "$work_root" "validation_summary" "$summary"

if [ "$lint_rc" -eq 0 ] && [ "$typecheck_rc" -eq 0 ] && [ "$synth_rc" -eq 0 ] \
  && [ "$cfnlint_rc" -eq 0 ] && [ "$test_rc" -eq 0 ] && [ "$nag_rc" -eq 0 ] && [ "$deps_rc" -eq 0 ]; then
  this_pass="PASS"
else
  this_pass="NEEDS_REVISION"
fi
mirror_note "$work_root" "module_quality_summary" "$this_pass"
if [ "$this_pass" = "NEEDS_REVISION" ]; then
  mirror_note "$work_root" "module_quality_rework" "true"
else
  mirror_note "$work_root" "module_quality_rework" "false"
fi

echo "lint_exit=${lint_rc}"
echo "typecheck_exit=${typecheck_rc}"
echo "synth_exit=${synth_rc}"
echo "cfn_lint_exit=${cfnlint_rc}"
echo "test_exit=${test_rc}"
echo "nag_exit=${nag_rc}"
echo "fmt_exit=${fmt_rc}"
echo "init_exit=${init_rc}"
echo "validate_exit=${valid_rc}"
echo "$summary"
echo "validation_summary=$summary"
echo "module_quality_summary=${this_pass}"

if [ "$test_rc" -ne 0 ] && [ -f "$work_dir/test.out" ]; then
  tail_esc="$(tail -40 "$work_dir/test.out" 2>/dev/null | sed ':a;N;$!ba;s/\r//g;s/\\/\\\\/g;s/"/\\"/g;s/\n/\\n/g' | head -c 3800)"
  echo "test_summary_file=$work_dir/test.out"
  echo "test_summary_tail=\"${tail_esc}\""
  gap_line="$(grep -E 'Error:|error:|FAIL|failed' "$work_dir/test.out" 2>/dev/null | tail -3 | tr '\n' '; ' | head -c 500)"
  if [ -n "$gap_line" ]; then
    echo "module_quality_gaps=test: $gap_line"
  fi
fi
