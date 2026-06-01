#!/usr/bin/env bash
# Self-contained terraform-bot stage runner — embed via heredoc in ONE execute_series.
# Ubuntu MCP container may reset between separate tool calls; all clone/write/validate for a subagent must stay in one series.
# Usage: bash -s <command> [args...] << 'TFBOT_STAGE_RUNNER' ... TFBOT_STAGE_RUNNER
# Commands: clone | validate | validate-and-pr | commit-pr | resolve-paths | discovery-check | discovery-scaffold
set -euo pipefail

SCRIPT_PACK_VERSION="${SCRIPT_PACK_VERSION:-20260531.37}"

# first_subdir_path_under returns the first direct child directory path without find|head (SIGPIPE under pipefail).
first_subdir_path_under() {
  local parent="${1:?parent_dir}"
  if [ ! -d "$parent" ]; then
    return 0
  fi
  find "$parent" -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null || true
}

# first_subdir_under returns the basename of the first direct child directory, or empty.
first_subdir_under() {
  local first
  first="$(first_subdir_path_under "${1:?parent_dir}")"
  if [ -n "$first" ]; then
    basename "$first"
  fi
}

# emit_test_handoff_lines prints machine-readable test failure context for architect notes (trace 573f84aa9000).
emit_test_handoff_lines() {
  local work_dir="${1:?work_dir}"
  local test_out="$work_dir/tf-test.out"
  echo "test_summary_file=$test_out"
  if [ ! -f "$test_out" ]; then
    return 0
  fi
  local tail_esc gap_line
  tail_esc="$(tail -40 "$test_out" 2>/dev/null | sed ':a;N;$!ba;s/\r//g;s/\\/\\\\/g;s/"/\\"/g;s/\n/\\n/g' | head -c 3800)"
  echo "test_summary_tail=\"$tail_esc\""
  gap_line="$(grep -E 'Error:|error:|FAIL|failed' "$test_out" 2>/dev/null | tail -3 | tr '\n' '; ' | head -c 500)"
  if [ -n "$gap_line" ]; then
    echo "module_quality_gaps=test: $gap_line"
  fi
}

# pick_discovery_sibling_dir chooses a scaffold template under <provider>/ (not first_subdir lexicographic).
pick_discovery_sibling_dir() {
  local provider_dir="${1:?provider_dir}"
  local module_dir="${2:?module_dir}"
  local suggested="${3:-}"

  if [ -n "$suggested" ] && [ -d "$provider_dir/$suggested" ]; then
    printf '%s' "$suggested"
    return 0
  fi

  local best="" best_score=0 d base score token
  token="${module_dir#aws_}"
  token="${token#google_}"
  token="${token#azurerm_}"

  for d in "$provider_dir"/*; do
    [ -d "$d" ] || continue
    base="$(basename "$d")"
    [ "$base" = "$module_dir" ] && continue
    score=0
    if printf '%s' "$base" | grep -Fq "$token"; then
      score=100
    elif [ ${#token} -ge 10 ] && printf '%s' "$base" | grep -Fq "${token:0:10}"; then
      score=80
    elif printf '%s' "$module_dir" | grep -Fq "$base"; then
      score=60
    else
      local seg
      for seg in $(printf '%s' "$token" | tr '_' ' '); do
        [ "${#seg}" -lt 5 ] && continue
        if printf '%s' "$base" | grep -Fq "$seg"; then
          score=$((score + 10))
        fi
      done
    fi
    if [ "$score" -gt "$best_score" ]; then
      best_score=$score
      best=$base
    fi
  done

  if [ -n "$best" ] && [ "$best_score" -gt 0 ]; then
    printf '%s' "$best"
    return 0
  fi

  first_subdir_under "$provider_dir"
}

require_embedded_invocation() {
  if [ "${TFBOT_EMBEDDED:-}" = "1" ]; then
    return 0
  fi
  if [ "${TFBOT_ALLOW_DIRECT:-}" = "1" ]; then
    return 0
  fi
  echo "script_pack_error=invoke_via_embed_tfbot_run_set_TFBOT_EMBEDDED=1" >&2
  return 1
}

mirror_note() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  local value="${3:?VALUE}"
  local notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"
  jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$notes" >"${notes}.tmp" \
    && mv "${notes}.tmp" "$notes"
  echo "mirrored:${key}" >&2
}

bootstrap_gh() {
  local git_token="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
  export GIT_TOKEN="$git_token" GH_TOKEN="$git_token" GITHUB_TOKEN="$git_token"
  export GIT_TERMINAL_PROMPT=0
  if [ -z "$git_token" ]; then
    echo "gh_env_present=false"
    return 1
  fi
  echo "gh_env_present=true"
  gh auth setup-git
  git config --global user.name "stackgen-terraform-bot"
  git config --global user.email "terraform-bot@stackgen.local"
}

git_clone_url() {
  local url="${1:?REPO_CLONE_URL}"
  local git_token="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
  if [[ "$url" =~ ^git@ ]]; then
    printf '%s' "$url"
    return 0
  fi
  if [[ "$url" =~ ^https://[^/@]+@ ]]; then
    printf '%s' "$url"
    return 0
  fi
  if [ -n "$git_token" ] && [[ "$url" =~ ^https://github\.com/ ]]; then
    printf 'https://x-access-token:%s@github.com/%s' "$git_token" "${url#https://github.com/}"
    return 0
  fi
  printf '%s' "$url"
}

git_with_auth_mode() {
  export GIT_TERMINAL_PROMPT=0
  if [ -n "${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}" ]; then
    git "$@"
    return $?
  fi
  git -c credential.helper= "$@"
}

remove_stale_clone_dir() {
  local repo_dir="${1:?REPO_DIR}"
  if [ -d "$repo_dir" ] && [ ! -d "$repo_dir/.git" ]; then
    rm -rf "$repo_dir"
  fi
}

# resolve_repo_dir returns the canonical git clone under $WORK_ROOT/repo.
# Legacy subagents sometimes cloned to repo_clone; normalize with a symlink so
# validate/commit-pr always share one tree.
resolve_repo_dir() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="$work_root/repo"
  local legacy_dir="$work_root/repo_clone"

  if [ -d "$repo_dir/.git" ]; then
    printf '%s' "$repo_dir"
    return 0
  fi

  if [ -d "$legacy_dir/.git" ]; then
    ln -sfn "$legacy_dir" "$repo_dir" 2>/dev/null || true
    if [ -e "$repo_dir/.git" ] || [ -L "$repo_dir" ]; then
      mirror_note "$work_root" "repo_clone_path" "$repo_dir"
      mirror_note "$work_root" "repo_path_normalized" "repo_clone_symlink_to_repo"
      printf '%s' "$repo_dir"
      return 0
    fi
    mirror_note "$work_root" "repo_clone_path" "$legacy_dir"
    printf '%s' "$legacy_dir"
    return 0
  fi

  printf '%s' "$repo_dir"
}

cmd_clone() {
  local work_root="${1:?WORK_ROOT}"
  local repo_clone_url="${2:?REPO_CLONE_URL}"
  local default_branch="${3:?DEFAULT_BRANCH}"
  local issue_or_pr="${4:?ISSUE_OR_PR_NUMBER}"
  local pr_head_ref="${5:-}"
  local pr_head_clone_url="${6:-$repo_clone_url}"

  local gh_ok=false
  if bootstrap_gh; then
    gh_ok=true
  else
    echo "gh_env_present=false"
  fi

  mkdir -p "$work_root"
  [ -f "$work_root/notes.json" ] || echo '{}' >"$work_root/notes.json"

  local repo_dir="$work_root/repo"
  local effective_clone_url
  effective_clone_url="$(git_clone_url "$repo_clone_url")"
  remove_stale_clone_dir "$repo_dir"
  if [ -d "$repo_dir/.git" ]; then
    cd "$repo_dir"
    if ! git_with_auth_mode fetch --all --prune 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "network"
      echo "clone_blocker=network"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
  else
    mkdir -p "$(dirname "$repo_dir")"
    if ! git_with_auth_mode clone "$effective_clone_url" "$repo_dir" 2>"$work_root/clone.err"; then
      remove_stale_clone_dir "$repo_dir"
      if [ "$gh_ok" = "false" ]; then
        mirror_note "$work_root" "clone_blocker" "auth_or_network"
        echo "clone_blocker=auth_or_network"
      else
        mirror_note "$work_root" "clone_blocker" "network"
        echo "clone_blocker=network"
      fi
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
    cd "$repo_dir"
  fi

  if [ -n "$pr_head_ref" ] && [ "$pr_head_clone_url" != "$repo_clone_url" ]; then
    if ! git_with_auth_mode remote add fork "$pr_head_clone_url" 2>/dev/null; then
      git_with_auth_mode remote set-url fork "$pr_head_clone_url"
    fi
    if ! git_with_auth_mode fetch fork "$pr_head_ref:$pr_head_ref" 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "branch"
      echo "clone_blocker=branch"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
    if ! git switch "$pr_head_ref" 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "branch"
      echo "clone_blocker=branch"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
  elif [ -n "$pr_head_ref" ]; then
    if ! git_with_auth_mode fetch origin "pull/${issue_or_pr}/head:pr-${issue_or_pr}" 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "branch"
      echo "clone_blocker=branch"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
    if ! git switch "pr-${issue_or_pr}" 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "branch"
      echo "clone_blocker=branch"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
  else
    if ! git switch "$default_branch" 2>/dev/null; then
      if ! git switch -c "$default_branch" "origin/$default_branch" 2>"$work_root/clone.err"; then
        mirror_note "$work_root" "clone_blocker" "branch"
        echo "clone_blocker=branch"
        cat "$work_root/clone.err" >&2 || true
        exit 1
      fi
    fi
  fi

  local sha
  sha="$(git rev-parse HEAD)"
  if [ "$gh_ok" = "true" ]; then
    mirror_note "$work_root" "clone_auth_mode" "token"
    mirror_note "$work_root" "push_requires_token" "false"
  else
    mirror_note "$work_root" "clone_auth_mode" "anonymous"
    mirror_note "$work_root" "push_requires_token" "true"
  fi
  mirror_note "$work_root" "repo_clone_path" "$repo_dir"
  mirror_note "$work_root" "repo_head_sha" "$sha"
  echo "repo_clone_path=$repo_dir"
  echo "repo_head_sha=$sha"
}

cmd_validate() {
  local work_root="${1:?WORK_ROOT}"
  local module_path="${2:?MODULE_PATH}"
  local work_dir="$work_root/.work"
  mkdir -p "$work_dir"

  if [ ! -d "$module_path" ]; then
    echo "validation_error=module_path_missing"
    echo "fmt_exit=1"
    echo "module_quality_summary=BLOCKED"
    return 1
  fi

  cd "$module_path"

  local tf
  if command -v tofu >/dev/null 2>&1; then
    tf="$(command -v tofu)"
  elif command -v terraform >/dev/null 2>&1; then
    tf="$(command -v terraform)"
  else
    echo "validation_error=no_iac_binary"
    echo "fmt_exit=1"
    echo "module_quality_summary=BLOCKED"
    return 1
  fi

  local tf_version fmt_rc=0 init_rc=0 valid_rc=0 test_rc=0
  tf_version="$("$tf" version | head -1)"
  echo "validate_started=true"
  echo "binary=${tf_version}"

  "$tf" fmt -recursive >"$work_dir/tf-fmt-apply.out" 2>&1 || true
  "$tf" fmt -recursive -check >"$work_dir/tf-fmt.out" 2>&1 || fmt_rc=$?
  "$tf" init -backend=false -input=false >"$work_dir/tf-init.out" 2>&1 || init_rc=$?
  "$tf" validate -no-color >"$work_dir/tf-validate.out" 2>&1 || valid_rc=$?

  if command -v tfsec >/dev/null 2>&1; then
    tfsec --no-color --soft-fail --format json . >"$work_dir/tfsec.json" 2>&1 &
    tfsec_pid=$!
  else
    echo "tfsec_not_found=true" >"$work_dir/tfsec.json"
    tfsec_pid=""
  fi

  if command -v checkov >/dev/null 2>&1; then
    checkov -d . --quiet --soft-fail --output json --output-file-path "$work_dir/checkov.json" >/dev/null 2>&1 &
    checkov_pid=$!
  else
    echo "checkov_not_found=true" >"$work_dir/checkov.json"
    checkov_pid=""
  fi

  if [ -n "$tfsec_pid" ]; then
    wait "$tfsec_pid" || true
  fi
  if [ -n "$checkov_pid" ]; then
    wait "$checkov_pid" || true
  fi

  if [ -d tests ] || compgen -G "*.tftest.hcl" >/dev/null; then
    "$tf" test -verbose >"$work_dir/tf-test.out" 2>&1 || test_rc=$?
  else
    test_rc=0
    echo "test_skipped=no_tftest_files" >"$work_dir/tf-test.out"
  fi

  local summary
  summary="binary=${tf_version}; fmt=$([ "$fmt_rc" -eq 0 ] && echo PASS || echo FAIL); init=$([ "$init_rc" -eq 0 ] && echo PASS || echo FAIL); validate=$([ "$valid_rc" -eq 0 ] && echo PASS || echo FAIL); test=$([ "$test_rc" -eq 0 ] && echo PASS || echo FAIL)"
  mirror_note "$work_root" "validation_summary" "$summary"

  local test_tail
  test_tail="$(tail -80 "$work_dir/tf-test.out" 2>/dev/null | tr '\n' ' ' | head -c 4000)"
  mirror_note "$work_root" "test_summary" "$test_tail"

  local findings=""
  [ -f "$work_dir/tfsec.json" ] && findings="${findings}tfsec_present "
  [ -f "$work_dir/checkov.json" ] && findings="${findings}checkov_present "
  mirror_note "$work_root" "static_security_findings" "${findings:-scan_skipped}"

  local module_slug fmt_result valid_result test_result this_pass prev_summary
  module_slug="$(printf '%s' "$module_path" | sed 's#^/##; s#/#_#g' | sed 's/[^a-zA-Z0-9._-]/_/g')"
  fmt_result="$([ "$fmt_rc" -eq 0 ] && echo PASS || echo FAIL)"
  valid_result="$([ "$valid_rc" -eq 0 ] && echo PASS || echo FAIL)"
  test_result="$([ "$test_rc" -eq 0 ] && echo PASS || echo FAIL)"
  mirror_note "$work_root" "quality_check_fmt:${module_slug}" "$fmt_result"
  mirror_note "$work_root" "quality_check_validate:${module_slug}" "$valid_result"
  mirror_note "$work_root" "quality_check_test:${module_slug}" "$test_result"
  mirror_note "$work_root" "quality_check_fmt" "$fmt_result"
  mirror_note "$work_root" "quality_check_validate" "$valid_result"
  mirror_note "$work_root" "quality_check_test" "$test_result"

  if [ "$fmt_rc" -eq 0 ] && [ "$valid_rc" -eq 0 ] && [ "$test_rc" -eq 0 ]; then
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

  echo "fmt_exit=${fmt_rc}"
  echo "init_exit=${init_rc}"
  echo "validate_exit=${valid_rc}"
  echo "test_exit=${test_rc}"
  echo "$summary"
  echo "validation_summary=$summary"
  if [ "$test_rc" -ne 0 ]; then
    emit_test_handoff_lines "$work_dir"
  fi
  echo "module_quality_summary=$([ "$fmt_rc" -eq 0 ] && [ "$valid_rc" -eq 0 ] && [ "$test_rc" -eq 0 ] && echo PASS || echo NEEDS_REVISION)"
}

# True when validate stdout shows fmt, init, and validate all succeeded (tests may still fail).
validate_out_fmt_validate_pass() {
  local out="${1:?}"
  grep -qE '^fmt_exit=0' "$out" || return 1
  grep -qE '^init_exit=0' "$out" || return 1
  grep -qE '^validate_exit=0' "$out" || return 1
}

# PR policy: never open a PR when init or validate failed. When DEFER_PR_UNTIL_PASS=true (default),
# open once fmt+init+validate pass (tests may still fail). When false, require full PASS (tests too).
should_open_pr_after_validate() {
  local validate_out="$1"
  local defer_pr="$2"
  if grep -qE '^module_quality_summary=BLOCKED' "$validate_out"; then
    return 1
  fi
  if ! validate_out_fmt_validate_pass "$validate_out"; then
    return 1
  fi
  if [ "$defer_pr" = "true" ]; then
    return 0
  fi
  grep -qE '^module_quality_summary=PASS' "$validate_out"
}

# validate-and-pr runs fmt/init/validate/test then optionally commit-pr (same as validate-execute-series embed).
# Env: WORK_ROOT, MODULE_PATH (required); REPO_FULL_NAME, ISSUE_OR_PR, BASE_BRANCH; DEFER_PR_UNTIL_PASS=true|false.
cmd_validate_and_pr() {
  local work_root module_path defer_pr
  work_root="$(normalize_work_root "${WORK_ROOT:-${1:-}}}")"
  export WORK_ROOT="$work_root"
  module_path="${MODULE_PATH:-${2:-}}"
  defer_pr="${DEFER_PR_UNTIL_PASS:-true}"
  local repo_full="${REPO_FULL_NAME:-}"
  local issue_or_pr="${ISSUE_OR_PR:-}"
  local base_branch="${BASE_BRANCH:-main}"

  if [ -z "$module_path" ]; then
    echo "error=missing_MODULE_PATH"
    exit 1
  fi
  if [ ! -d "$module_path" ]; then
    echo "validation_error=module_path_missing path=$module_path"
    exit 1
  fi

  if ! command -v tofu >/dev/null 2>&1 && ! command -v terraform >/dev/null 2>&1; then
    echo "validation_error=no_iac_binary"
    echo "fmt_exit=1"
    echo "module_quality_summary=BLOCKED"
    exit 1
  fi

  local validate_out="$work_root/.work/validate.out"
  mkdir -p "$work_root/.work"
  set +e
  cmd_validate "$work_root" "$module_path" | tee "$validate_out"
  local validate_rc=$?
  set -e

  if [ ! -s "$validate_out" ]; then
    echo "validation_error=empty_validate_stdout"
    echo "validate_exit=$validate_rc"
    echo "module_quality_summary=BLOCKED"
    exit 1
  fi

  if ! grep -qE '^fmt_exit=' "$validate_out"; then
    echo "validation_error=missing_fmt_exit_marker"
    echo "validate_exit=$validate_rc"
    echo "validate_out_bytes=$(wc -c < "$validate_out" | tr -d ' ')"
    tail -20 "$validate_out" || true
    echo "module_quality_summary=BLOCKED"
    exit 1
  fi

  if grep -qE '^module_quality_summary=BLOCKED' "$validate_out"; then
    echo "module_quality_summary=BLOCKED"
    exit 1
  fi

  if grep -qE '^module_quality_summary=NEEDS_REVISION' "$validate_out"; then
    echo "module_quality_rework=true"
  fi

  if validate_out_fmt_validate_pass "$validate_out"; then
    echo "pr_eligible_fmt_validate=true"
  else
    echo "pr_eligible_fmt_validate=false"
  fi

  local should_open_pr="false"
  if should_open_pr_after_validate "$validate_out" "$defer_pr"; then
    should_open_pr="true"
  elif ! grep -qE '^fmt_exit=0' "$validate_out"; then
    echo "pr_deferred=fmt_failed"
  elif ! grep -qE '^init_exit=0' "$validate_out"; then
    echo "pr_deferred=init_failed"
  elif ! grep -qE '^validate_exit=0' "$validate_out"; then
    echo "pr_deferred=validate_failed"
  elif [ "$defer_pr" != "true" ]; then
    echo "pr_deferred=tests_not_pass"
  else
    echo "pr_deferred=quality_gate"
  fi

  if [ "$should_open_pr" = "true" ]; then
    if [ -z "$repo_full" ] || [ -z "$issue_or_pr" ]; then
      echo "push_skipped=missing_repo_or_issue"
      echo "pr_deferred=missing_repo_or_issue"
      mirror_note "$work_root" "pr_deferred" "missing_repo_or_issue"
    else
      local commit_out="$work_root/.work/commit-pr.out"
      set +e
      cmd_commit_pr "$work_root" "$repo_full" "$issue_or_pr" "" "$base_branch" | tee "$commit_out"
      local commit_rc=$?
      set -e
      grep -E '^(pr_url|working_branch|pr_title|pr_blocker|pr_error|pr_prepushed|pr_draft)=' "$commit_out" || true
      if grep -qE '^pr_url=https://' "$commit_out" 2>/dev/null; then
        echo "pr_deferred=false"
        mirror_note "$work_root" "pr_deferred" "false"
      elif grep -qE '^pr_blocker=auth' "$commit_out" 2>/dev/null; then
        echo "pr_deferred=push_auth"
        mirror_note "$work_root" "pr_deferred" "push_auth"
      elif grep -qE '^pr_error=nothing_to_commit' "$commit_out" 2>/dev/null; then
        echo "pr_deferred=nothing_to_commit"
        mirror_note "$work_root" "pr_deferred" "nothing_to_commit"
      elif [ "$commit_rc" -ne 0 ]; then
        echo "pr_deferred=commit_failed"
        mirror_note "$work_root" "pr_deferred" "commit_failed"
        tail -5 "$commit_out" 2>/dev/null || true
      else
        echo "pr_deferred=commit_no_pr_url"
        mirror_note "$work_root" "pr_deferred" "commit_no_pr_url"
      fi
    fi
  fi

  grep -E '^(fmt_exit|init_exit|validate_exit|test_exit|module_quality_summary|validation_summary|test_summary_file|test_summary_tail|module_quality_gaps)=' "$validate_out" || true
  echo "validate_markers_file=$validate_out"
  echo "script_pack_version=$SCRIPT_PACK_VERSION"
}

note_val() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  if [ ! -f "$work_root/notes.json" ]; then
    return 0
  fi
  jq -r --arg k "$key" '.[$k] // empty' "$work_root/notes.json" 2>/dev/null || true
}

humanize_slug() {
  local s="${1:-module}"
  s="${s//_/ }"
  printf '%s' "$s"
}

primary_module_relpath() {
  local repo_dir="${1:?REPO_DIR}"
  local work_root="${2:?WORK_ROOT}"
  local from_notes
  from_notes="$(note_val "$work_root" module_paths)"
  if [ -n "$from_notes" ] && [ "$from_notes" != "null" ]; then
    if echo "$from_notes" | jq -e . >/dev/null 2>&1; then
      from_notes="$(echo "$from_notes" | jq -r '.[0] // empty' 2>/dev/null || true)"
    fi
    from_notes="${from_notes#"$repo_dir"/}"
    from_notes="${from_notes#/}"
    if [ -n "$from_notes" ] && [ -d "$repo_dir/$from_notes" ]; then
      printf '%s' "$from_notes"
      return 0
    fi
  fi

  local first_file
  first_file="$(git -C "$repo_dir" diff --cached --name-only 2>/dev/null | grep -E '\.(tf|tf\.json|tftest\.hcl|yaml|yml|md)$' | head -1 || true)"
  if [ -z "$first_file" ]; then
    first_file="$(git -C "$repo_dir" diff --cached --name-only 2>/dev/null | head -1 || true)"
  fi
  if [ -z "$first_file" ]; then
    printf '.'
    return 0
  fi

  local dir="$first_file"
  while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
    if [ -n "$(find "$repo_dir/$dir" -maxdepth 1 -name '*.tf' -print -quit 2>/dev/null)" ]; then
      printf '%s' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  printf '.'
}

stackgen_summary_line() {
  local module_dir="${1:?MODULE_DIR}"
  local yaml="$module_dir/.stackgen/stackgen.yaml"
  if [ ! -f "$yaml" ]; then
    return 0
  fi
  awk '
    /^description:/ {
      if (match($0, />[[:space:]]*$/)) {
        getline
        gsub(/^[[:space:]]+/, "")
        print
        exit
      }
      sub(/^description:[[:space:]]*/, "")
      print
      exit
    }
  ' "$yaml" 2>/dev/null || true
}

list_tf_resource_types() {
  local module_dir="${1:?MODULE_DIR}"
  find "$module_dir" -maxdepth 1 -name '*.tf' -print0 2>/dev/null |
    xargs -0 grep -hE '^resource "[^"]+"' 2>/dev/null |
    sed -E "s/^resource \"([^\"]+)\".*/- \`\1\`/" |
    sort -u |
    head -8
}

quality_badge() {
  local work_root="$1" key="$2"
  local val
  val="$(note_val "$work_root" "$key")"
  if [ "$val" = "PASS" ]; then
    printf '✅ PASS'
  elif [ -n "$val" ]; then
    printf '❌ %s' "$val"
  else
    printf '— (not recorded)'
  fi
}

build_pr_title() {
  local work_root="$1" module_relpath="$2" change_kind="$3"
  local provider module_name human_name summary_line
  provider="${module_relpath%%/*}"
  module_name="$(basename "$module_relpath")"
  human_name="$(humanize_slug "$module_name")"
  summary_line="$(stackgen_summary_line "$work_root/repo/$module_relpath")"
  if [ -n "$summary_line" ]; then
    human_name="$(printf '%s' "$summary_line" | sed -E 's/[[:space:]]+$//' | head -c 60)"
  fi

  case "$change_kind" in
    add)
      if [ "$provider" = "aws" ] || [ "$provider" = "gcp" ] || [ "$provider" = "azurerm" ]; then
        printf 'feat(%s): add %s module' "$provider" "$human_name"
      else
        printf 'feat(%s): add %s Terraform module' "$(basename "$module_relpath")" "$human_name"
      fi
      ;;
    update)
      if [ "$provider" = "aws" ] || [ "$provider" = "gcp" ] || [ "$provider" = "azurerm" ]; then
        printf 'feat(%s): update %s module' "$provider" "$human_name"
      else
        printf 'feat: update %s' "$human_name"
      fi
      ;;
    *)
      printf 'feat: terraform module update for %s' "$human_name"
      ;;
  esac
}

build_pr_body() {
  local work_root="$1" repo_full_name="$2" issue_or_pr="$3" module_relpath="$4" change_kind="$5"
  local module_dir="$work_root/repo/$module_relpath"
  local summary_line resource_lines provider module_name
  summary_line="$(stackgen_summary_line "$module_dir")"
  provider="${module_relpath%%/*}"
  module_name="$(basename "$module_relpath")"
  resource_lines="$(list_tf_resource_types "$module_dir")"

  if [ -z "$summary_line" ] && [ -f "$module_dir/README.md" ]; then
    summary_line="$(awk 'NF {print; exit}' "$module_dir/README.md" 2>/dev/null | sed 's/^#*[[:space:]]*//')"
  fi
  if [ -z "$summary_line" ]; then
    summary_line="Updates the \`$module_relpath\` Terraform module."
  fi

  cat <<EOF
## Summary

${summary_line}

## Motivation

Closes ${repo_full_name}#${issue_or_pr}

## What's included

EOF

  if [ "$change_kind" = "add" ]; then
    printf -- "- New module at \`%s\`\n" "$module_relpath"
  else
    printf -- "- Updates under \`%s\`\n" "$module_relpath"
  fi

  git -C "$work_root/repo" diff --cached --name-status 2>/dev/null |
    sed 's/^/  - /' |
    head -20

  cat <<EOF

## Terraform resources

EOF

  if [ -n "$resource_lines" ]; then
    printf '%s\n' "$resource_lines"
  else
    printf '%s\n' "- See *.tf files in the module directory"
  fi

  cat <<EOF

## Validation

| Check | Result |
|-------|--------|
| \`terraform fmt\` | $(quality_badge "$work_root" quality_check_fmt) |
| \`terraform validate\` | $(quality_badge "$work_root" quality_check_validate) |
| \`terraform test\` | $(quality_badge "$work_root" quality_check_test) |
| Module quality | $(note_val "$work_root" module_quality_summary) |

## Reviewer notes

- Generated by the \`terraform-module-update\` workflow (StackGen terraform-bot).
- Please confirm variable defaults, security constraints, and any org-specific wiring before merge.
EOF

  local scaffold
  scaffold="$(note_val "$work_root" scaffold_summary)"
  if [ -n "$scaffold" ]; then
    printf '\n### Scaffold context\n\n%s\n' "$scaffold"
  fi

  append_quality_failure_details "$work_root"
}

# append_quality_failure_details adds draft-PR failure commentary when checks did not all pass.
append_quality_failure_details() {
  local work_root="$1"
  local qs vs ts fmt_q val_q test_q
  qs="$(note_val "$work_root" module_quality_summary)"
  if [ "$qs" = "PASS" ]; then
    return 0
  fi
  if [ "$qs" = "BLOCKED" ]; then
    return 0
  fi

  fmt_q="$(note_val "$work_root" quality_check_fmt)"
  val_q="$(note_val "$work_root" quality_check_validate)"
  test_q="$(note_val "$work_root" quality_check_test)"
  vs="$(note_val "$work_root" validation_summary)"
  ts="$(note_val "$work_root" test_summary)"

  cat <<EOF

> **Draft PR** — automated quality checks did not all pass. Do not merge until the table above shows PASS.

## Failed check details

EOF

  if [ -n "$vs" ]; then
    printf -- '- **Summary:** `%s`\n' "$vs"
  fi
  if [ "$fmt_q" = "FAIL" ]; then
    printf -- '- **fmt:** failed — run `terraform fmt -recursive` in the module directory\n'
  fi
  if [ "$val_q" = "FAIL" ]; then
    printf -- '- **validate:** failed — see validate output below\n'
  fi
  if [ "$test_q" = "FAIL" ]; then
    printf -- '- **test:** failed — see test output below\n'
  fi

  if [ -f "$work_root/.work/tf-validate.out" ] && [ "$val_q" = "FAIL" ]; then
    cat <<EOF

### Validate output (last 80 lines)

\`\`\`
EOF
    tail -80 "$work_root/.work/tf-validate.out" 2>/dev/null || true
    printf '%s\n' '```'
  fi

  if [ -f "$work_root/.work/tf-test.out" ] && [ "$test_q" = "FAIL" ]; then
    cat <<EOF

### Test output (last 120 lines)

\`\`\`
EOF
    tail -120 "$work_root/.work/tf-test.out" 2>/dev/null || true
    printf '%s\n' '```'
  fi

  if [ -n "$ts" ] && [ "$test_q" = "FAIL" ] && [ ! -f "$work_root/.work/tf-test.out" ]; then
    cat <<EOF

### Test output (truncated)

\`\`\`
${ts}
\`\`\`
EOF
  fi
}

build_commit_message() {
  local repo_full_name="$1" issue_or_pr="$2" pr_title="$3"
  printf '%s\n\nCloses %s#%s' "$pr_title" "$repo_full_name" "$issue_or_pr"
}

branch_slug_from_module() {
  local module_relpath="$1"
  local provider module_name
  provider="${module_relpath%%/*}"
  module_name="$(basename "$module_relpath")"
  module_name="${module_name//_/-}"
  if [ "$provider" != "$module_name" ]; then
    printf 'terraform-bot/%s-%s-%s' "$provider" "$module_name" "$(date +%Y%m%d)"
  else
    printf 'terraform-bot/%s-%s' "$module_name" "$(date +%Y%m%d)"
  fi
}

cmd_commit_pr() {
  local work_root="${1:?WORK_ROOT}"
  local repo_full_name="${2:?REPO_FULL_NAME}"
  local issue_or_pr="${3:?ISSUE_OR_PR_NUMBER}"
  local commit_msg="${4:-}"
  local base_branch="${5:-main}"

  if ! bootstrap_gh; then
    mirror_note "$work_root" "pr_blocker" "auth"
    mirror_note "$work_root" "push_requires_token" "true"
    echo "pr_blocker=auth"
    echo "gh_env_present=false"
    return 1
  fi

  local repo_dir
  repo_dir="$(resolve_repo_dir "$work_root")"
  if [ ! -d "$repo_dir/.git" ] && [ ! -e "$repo_dir/.git" ]; then
    mirror_note "$work_root" "pr_blocker" "no_clone"
    echo "pr_error=no_clone"
    return 1
  fi

  cd "$repo_dir"
  git add -A
  if git diff --cached --quiet; then
    echo "pr_error=nothing_to_commit"
    return 1
  fi

  local module_relpath change_kind added_count branch pr_title pr_body_file commit_body
  module_relpath="$(primary_module_relpath "$repo_dir" "$work_root")"
  if [ "$module_relpath" = "." ]; then
    module_relpath="$(git diff --cached --name-only | head -1 | xargs dirname 2>/dev/null || echo ".")"
  fi

  branch="${WORKING_BRANCH:-}"
  if [ -z "$branch" ]; then
    branch="$(note_val "$work_root" working_branch)"
  fi
  if [ -z "$branch" ]; then
    branch="$(branch_slug_from_module "$module_relpath")"
  fi
  git switch -c "$branch" 2>/dev/null || git switch "$branch"

  added_count="$(git diff --cached --diff-filter=A --name-only | wc -l | tr -d ' ')"
  if [ "$added_count" -ge 3 ] && git diff --cached --diff-filter=A --name-only | grep -q "^${module_relpath%/}/"; then
    change_kind="add"
  else
    change_kind="update"
  fi

  pr_title="$(build_pr_title "$work_root" "$module_relpath" "$change_kind")"
  pr_body_file="$work_root/.work/pr-body.md"
  mkdir -p "$work_root/.work"
  build_pr_body "$work_root" "$repo_full_name" "$issue_or_pr" "$module_relpath" "$change_kind" >"$pr_body_file"

  if [ -n "$commit_msg" ]; then
    git commit -m "$commit_msg" || {
      echo "pr_error=nothing_to_commit"
      return 1
    }
  else
    commit_body="$(build_commit_message "$repo_full_name" "$issue_or_pr" "$pr_title")"
    git commit -m "$commit_body" || {
      echo "pr_error=nothing_to_commit"
      return 1
    }
  fi

  if ! git push -u origin HEAD 2>"$work_root/.work/push.err"; then
    mirror_note "$work_root" "pr_blocker" "push_failed"
    echo "pr_blocker=push_failed"
    cat "$work_root/.work/push.err" >&2 || true
    return 1
  fi

  local pr_url="" draft_args=() quality_summary pr_draft_flag="false"
  quality_summary="$(note_val "$work_root" module_quality_summary)"
  if [ "$quality_summary" != "PASS" ]; then
    draft_args=(--draft)
    pr_draft_flag="true"
    mirror_note "$work_root" "pr_draft" "true"
  else
    mirror_note "$work_root" "pr_draft" "false"
  fi

  pr_url="$(note_val "$work_root" pr_url)"
  if [ -z "$pr_url" ] || [ "$pr_url" = "null" ]; then
    pr_url="$(gh pr list --repo "$repo_full_name" --head "$branch" --json url -q '.[0].url' 2>/dev/null || true)"
  fi
  if [ -z "$pr_url" ] || [ "$pr_url" = "null" ]; then
    pr_url="$(gh pr create --repo "$repo_full_name" --base "$base_branch" --head "$branch" \
      --title "$pr_title" --body-file "$pr_body_file" "${draft_args[@]}")"
  elif [ -f "$pr_body_file" ] && [ "${#draft_args[@]}" -gt 0 ]; then
    gh pr edit "$pr_url" --repo "$repo_full_name" --body-file "$pr_body_file" 2>/dev/null || true
  fi

  mirror_note "$work_root" "working_branch" "$branch"
  mirror_note "$work_root" "pr_url" "$pr_url"
  mirror_note "$work_root" "pr_title" "$pr_title"
  mirror_note "$work_root" "pr_deferred" "false"
  echo "working_branch=$branch"
  echo "pr_url=$pr_url"
  echo "pr_title=$pr_title"
  echo "pr_draft=$pr_draft_flag"
}

cmd_resolve_paths() {
  local work_root="${1:?WORK_ROOT}"
  local repo_clone="${2:?REPO_CLONE_PATH}"
  local default_branch="${3:?DEFAULT_BRANCH}"
  local hint_csv="${4:-}"

  [ -f "$work_root/notes.json" ] || echo '{}' >"$work_root/notes.json"
  [ -n "$hint_csv" ] && mirror_note "$work_root" "target_module_hints" "$hint_csv"

  repo_clone="$(resolve_repo_dir "$work_root")"
  mirror_note "$work_root" "repo_clone_path" "$repo_clone"

  cd "$repo_clone"
  mapfile -t hints < <(printf '%s' "$hint_csv" | tr ',' '\n' | sed '/^$/d' | head -20)

  local candidates=()
  if [ "${#hints[@]}" -gt 0 ]; then
    local find_args=("$repo_clone" "-type" "d" "(")
    local first=1
    local h
    for h in "${hints[@]}"; do
      [ "$first" -eq 1 ] || find_args+=("-o")
      find_args+=("-name" "$h")
      first=0
    done
    find_args+=(")" "-not" "-path" "*/.terraform/*" "-not" "-path" "*/.git/*")
    while IFS= read -r d; do
      [ -n "$d" ] && candidates+=("$d")
    done < <(find "${find_args[@]}" 2>/dev/null | sort -u)
  fi

  local pr_touched=()
  while IFS= read -r f; do
    [ -n "$f" ] && pr_touched+=("$(dirname "$f")")
  done < <(git diff --name-only "origin/${default_branch}...HEAD" 2>/dev/null | sort -u)

  is_tf_module() {
    local dir="$1"
    [ -n "$(find "$dir" -maxdepth 1 -name '*.tf' -print -quit 2>/dev/null)" ]
  }

  local filtered=()
  local d
  for d in "${candidates[@]}"; do
    is_tf_module "$d" && filtered+=("$d")
  done

  local confidence="not_found"
  local module_paths_json="[]"

  if [ "${#filtered[@]}" -eq 1 ]; then
    confidence="probable"
    if [ "${#pr_touched[@]}" -gt 0 ]; then
      for d in "${filtered[@]}"; do
        local t
        for t in "${pr_touched[@]}"; do
          if [[ "$t" == "$d"* ]]; then
            confidence="exact"
            break 2
          fi
        done
      done
    fi
    module_paths_json="$(printf '%s\n' "${filtered[@]}" | jq -R . | jq -s .)"
  fi

  if [ "${#filtered[@]}" -gt 1 ]; then
    confidence="ambiguous"
    module_paths_json="$(printf '%s\n' "${filtered[@]}" | head -5 | jq -R . | jq -s .)"
  fi

  if [ "${#filtered[@]}" -eq 0 ] && [ "${#hints[@]}" -gt 0 ]; then
    for h in "${hints[@]}"; do
      while IFS= read -r d; do
        is_tf_module "$d" && filtered+=("$d")
      done < <(
        find "$repo_clone" -type d -not -path '*/.terraform/*' -not -path '*/.git/*' 2>/dev/null |
          rg -i "$h" || true
      )
    done
    if [ "${#filtered[@]}" -eq 1 ]; then
      confidence="probable"
      module_paths_json="$(printf '%s\n' "${filtered[@]}" | jq -R . | jq -s .)"
    fi
    if [ "${#filtered[@]}" -gt 1 ]; then
      confidence="ambiguous"
      module_paths_json="$(printf '%s\n' "${filtered[@]}" | head -5 | jq -R . | jq -s .)"
    fi
  fi

  mirror_note "$work_root" "module_resolution_confidence" "$confidence"
  local paths_csv
  paths_csv="$(echo "$module_paths_json" | jq -r 'join(",")')"
  [ -n "$paths_csv" ] && mirror_note "$work_root" "module_paths" "$paths_csv"
  echo "module_resolution_confidence=$confidence"
  echo "module_paths=$paths_csv"
}

# normalize_work_root expands literal $HOME tokens agents sometimes paste instead of {{work_root}}.
normalize_work_root() {
  local wr="${1:?work_root}"
  if [[ "$wr" == *'$HOME'* ]]; then
    wr="${wr//\$HOME/${HOME}}"
  fi
  if [[ "$wr" == *'${HOME}'* ]]; then
    wr="${wr//'${HOME}'/${HOME}}"
  fi
  printf '%s' "$wr"
}

hydrate_trigger_json() {
  if [ -n "${TRIGGER_JSON:-}" ]; then
    return 0
  fi
  if [ -n "${TRIGGER_JSON_B64:-}" ]; then
    local decoded
    decoded="$(printf '%s' "$TRIGGER_JSON_B64" | base64 -d 2>/dev/null)" || decoded=""
    if [ -n "$decoded" ] && printf '%s' "$decoded" | jq -e . >/dev/null 2>&1; then
      TRIGGER_JSON="$decoded"
      export TRIGGER_JSON
      return 0
    fi
  fi
  return 1
}

# hydrate_trigger_from_notes rebuilds TRIGGER_JSON from planner/subagent notes on disk (trace 90f941703011: placeholder TRIGGER_JSON_B64).
hydrate_trigger_from_notes() {
  local work_root="${1:?WORK_ROOT}"
  local notes="$work_root/notes.json"
  if [ ! -f "$notes" ]; then
    return 1
  fi
  local title body num
  title="$(jq -r '.issue_details.title // .issue_title // empty' "$notes" 2>/dev/null)"
  body="$(jq -r '.issue_details.body // .issue_body // empty' "$notes" 2>/dev/null)"
  num="$(jq -r '.issue_or_pr_number // .issue_details.number // empty' "$notes" 2>/dev/null)"
  if [ -z "$title" ] && [ -z "$body" ]; then
    return 1
  fi
  if [ -n "$num" ] && [ "$num" != "null" ]; then
    TRIGGER_JSON="$(jq -n --arg t "$title" --arg b "$body" --argjson n "$num" '{issue:{title:$t,body:$b,number:$n}}')"
  else
    TRIGGER_JSON="$(jq -n --arg t "$title" --arg b "$body" '{issue:{title:$t,body:$b}}')"
  fi
  export TRIGGER_JSON
  return 0
}

# hydrate_trigger_from_issue_env uses exports the architect passes in create_agent context (no base64 required).
hydrate_trigger_from_issue_env() {
  if [ -z "${ISSUE_TITLE:-}" ]; then
    return 1
  fi
  if [ -n "${ISSUE_OR_PR:-}" ]; then
    TRIGGER_JSON="$(jq -n --arg t "$ISSUE_TITLE" --arg b "${ISSUE_BODY:-}" --argjson n "$ISSUE_OR_PR" '{issue:{title:$t,body:$b,number:$n}}' 2>/dev/null)" || true
  fi
  if [ -z "${TRIGGER_JSON:-}" ]; then
    TRIGGER_JSON="$(jq -n --arg t "$ISSUE_TITLE" --arg b "${ISSUE_BODY:-}" '{issue:{title:$t,body:$b}}')"
  fi
  export TRIGGER_JSON
  return 0
}

infer_discovery_module_from_trigger() {
  local raw="${TRIGGER_JSON:-}"
  local title body combined
  title="$(printf '%s' "$raw" | jq -r '.issue.title // .pull_request.title // empty' | tr '[:upper:]' '[:lower:]')"
  body="$(printf '%s' "$raw" | jq -r '.issue.body // .pull_request.body // empty' | tr '[:upper:]' '[:lower:]')"
  combined="$title $body"

  PROVIDER_ROOT="${PROVIDER_ROOT:-aws}"
  if printf '%s' "$combined" | grep -Eq 'azure|azurerm'; then
    PROVIDER_ROOT="azurerm"
  elif printf '%s' "$combined" | grep -Eq 'gcp|google|gke'; then
    PROVIDER_ROOT="gcp"
  fi

  MODULE_DIR="${MODULE_DIR:-}"
  SIBLING_DIR="${SIBLING_DIR:-}"

  if [ -z "$MODULE_DIR" ] && printf '%s' "$combined" | grep -Eq 'blue.?green|blue/green'; then
    if printf '%s' "$combined" | grep -Eq 'ecs|fargate|container|microservice'; then
      MODULE_DIR="aws_ecs_service_blue_green"
      SIBLING_DIR="aws_ecs_service"
      PROVIDER_ROOT="aws"
    fi
  fi
  if [ -z "$MODULE_DIR" ] && printf '%s' "$combined" | grep -Eq 'scheduler|schedule'; then
    MODULE_DIR="aws_scheduler_schedule"
    SIBLING_DIR="aws_cloudwatch_event_rule"
    PROVIDER_ROOT="aws"
  fi
  if [ -z "$MODULE_DIR" ] && printf '%s' "$combined" | grep -Eq 'event.?bridge.?pipe|pipes'; then
    MODULE_DIR="aws_pipes_pipe"
    SIBLING_DIR="aws_sqs_queue"
    PROVIDER_ROOT="aws"
  fi
  if [ -z "$MODULE_DIR" ] && printf '%s' "$combined" | grep -Eq 'verified.?access|verifiedaccess'; then
    MODULE_DIR="aws_verifiedaccess_trust_provider"
    SIBLING_DIR="aws_ec2_client_vpn_endpoint"
    PROVIDER_ROOT="aws"
  fi
  if [ -z "$MODULE_DIR" ]; then
    MODULE_DIR="$(printf '%s' "$combined" | grep -Eo '(aws|google|azurerm)_[a-z0-9_]{3,}' | head -1 || true)"
  fi
  if [ -z "$MODULE_DIR" ] && [ -n "${ISSUE_TITLE:-}" ]; then
    MODULE_DIR="$(printf '%s' "${ISSUE_TITLE}" | tr '[:upper:]' '[:lower:]' | grep -Eo '(aws|google|azurerm)_[a-z0-9_]{3,}' | head -1 || true)"
  fi
  export MODULE_DIR PROVIDER_ROOT SIBLING_DIR
}

discovery_scaffold_finalize_with_validate() {
  local work_root="${1:?WORK_ROOT}"
  local module_path="${2:?MODULE_PATH}"
  local confidence="${3:?CONFIDENCE}"
  local scaffold_summary="${4:?SCAFFOLD_SUMMARY}"

  mirror_note "$work_root" "module_paths" "$module_path"
  mirror_note "$work_root" "module_resolution_confidence" "$confidence"

  echo "module_paths=$module_path"
  echo "module_resolution_confidence=$confidence"
  echo "scaffold_summary=$scaffold_summary"

  local validate_out="$work_root/.work/discovery-validate.out"
  mkdir -p "$work_root/.work"
  if ! command -v tofu >/dev/null 2>&1 && ! command -v terraform >/dev/null 2>&1; then
    echo "validation_error=no_iac_binary"
    echo "fmt_exit=1"
    echo "module_quality_summary=BLOCKED"
    echo "discovery_greenfield_validated=true"
    echo "script_pack_version=$SCRIPT_PACK_VERSION"
    exit 1
  fi

  set +e
  cmd_validate "$work_root" "$module_path" | tee "$validate_out"
  local validate_rc=$?
  set -e

  if [ ! -s "$validate_out" ]; then
    echo "validation_error=empty_validate_stdout"
    echo "validate_exit=$validate_rc"
    echo "module_quality_summary=BLOCKED"
    echo "discovery_greenfield_validated=true"
    echo "script_pack_version=$SCRIPT_PACK_VERSION"
    exit 1
  fi

  if ! grep -qE '^fmt_exit=' "$validate_out"; then
    echo "validation_error=missing_fmt_exit_marker"
    echo "validate_exit=$validate_rc"
    echo "module_quality_summary=BLOCKED"
    echo "discovery_greenfield_validated=true"
    echo "script_pack_version=$SCRIPT_PACK_VERSION"
    exit 1
  fi

  grep -E '^(fmt_exit|init_exit|validate_exit|test_exit|module_quality_summary|validation_summary|test_summary_file|test_summary_tail|module_quality_gaps)=' "$validate_out" || true
  grep -E '^module_quality_summary=' "$validate_out" | tail -1 || true
  echo "validate_markers_file=$validate_out"
  echo "discovery_greenfield_validated=true"
  echo "script_pack_version=$SCRIPT_PACK_VERSION"
}

cmd_discovery_scaffold() {
  local work_root
  work_root="$(normalize_work_root "${1:-${WORK_ROOT:-}}")"
  export WORK_ROOT="$work_root"
  local repo_dir="$work_root/repo"

  if [ ! -d "$repo_dir/.git" ] && [ ! -e "$repo_dir/.git" ]; then
    echo "scaffold_error=no_repo_clone"
    exit 1
  fi

  if [ "${TFBOT_ALLOW_DIRECT:-}" != "1" ]; then
    if [ ! -x "$work_root/.pack/stage-runner.sh" ]; then
      echo "scaffold_error=missing_stage_runner path=$work_root/.pack/stage-runner.sh hint=use_absolute_work_root_from_spawn_context_not_literal_HOME"
      exit 1
    fi
  fi

  if ! hydrate_trigger_json; then
    hydrate_trigger_from_issue_env || hydrate_trigger_from_notes "$work_root" || true
  fi
  if [ -z "${TRIGGER_JSON:-}" ] && [ -n "${ISSUE_TITLE:-}" ]; then
    hydrate_trigger_from_issue_env || true
  fi
  if [ -z "${TRIGGER_JSON:-}" ]; then
    if [ -z "${MODULE_DIR:-}" ] || [ -z "${PROVIDER_ROOT:-}" ]; then
      echo "scaffold_error=missing_trigger_json"
      echo "hint=export ISSUE_TITLE ISSUE_BODY ISSUE_OR_PR from read_notes issue_details, or valid TRIGGER_JSON_B64 — never placeholder base64 text"
      exit 1
    fi
  fi

  if [ -z "${MODULE_DIR:-}" ] || [ -z "${PROVIDER_ROOT:-}" ]; then
    infer_discovery_module_from_trigger
  fi

  if [ -z "${MODULE_DIR:-}" ]; then
    echo "scaffold_error=unable_to_infer_module_dir"
    echo "hint=export MODULE_DIR and PROVIDER_ROOT from issue title/body hints"
    exit 1
  fi

  local check_out="$work_root/.work/discovery-check.out"
  mkdir -p "$work_root/.work"
  cmd_discovery_check "$work_root" "$repo_dir" "$PROVIDER_ROOT" "$MODULE_DIR" | tee "$check_out"

  local confidence
  confidence="$(grep -E '^module_resolution_confidence=' "$check_out" | tail -1 | cut -d= -f2- || true)"
  if [ "$confidence" = "exact" ]; then
    local module_path
    module_path="$(grep -E '^module_paths=' "$check_out" | tail -1 | cut -d= -f2- || true)"
    if [ -z "$module_path" ] || [ ! -d "$module_path" ]; then
      echo "scaffold_error=existing_module_path_missing"
      exit 1
    fi
    discovery_scaffold_finalize_with_validate "$work_root" "$module_path" "exact" "existing_module_revalidated"
    return 0
  fi

  local target="$repo_dir/$PROVIDER_ROOT/$MODULE_DIR"
  SIBLING_DIR="$(pick_discovery_sibling_dir "$repo_dir/$PROVIDER_ROOT" "$MODULE_DIR" "${SIBLING_DIR:-}")"
  local sibling="$repo_dir/$PROVIDER_ROOT/$SIBLING_DIR"
  if [ ! -d "$sibling" ]; then
    sibling="$(first_subdir_path_under "$repo_dir/$PROVIDER_ROOT")"
    [ -n "$sibling" ] && SIBLING_DIR="$(basename "$sibling")"
  fi
  if [ -z "$sibling" ] || [ ! -d "$sibling" ]; then
    echo "scaffold_error=no_sibling_module provider=$PROVIDER_ROOT"
    exit 1
  fi

  local issue_num=""
  if [ -n "${TRIGGER_JSON:-}" ]; then
    issue_num="$(printf '%s' "$TRIGGER_JSON" | jq -r '.issue.number // .pull_request.number // empty')"
  fi

  mkdir -p "$(dirname "$target")"
  cp -a "$sibling" "$target"

  {
    printf '%s\n' "# $MODULE_DIR" "" "Discovery module scaffold for issue #${issue_num:-unknown}." "" "Copied from sibling $(basename "$sibling") and adapted for workflow validation."
  } >"$target/README.md"

  if [ -f "$target/.stackgen/stackgen.yaml" ]; then
    sed -i.bak "s/$(basename "$sibling")/$MODULE_DIR/g" "$target/.stackgen/stackgen.yaml" 2>/dev/null || true
    rm -f "$target/.stackgen/stackgen.yaml.bak"
  fi

  local _json
  for _json in variables.tf.json outputs.tf.json; do
    if [ ! -f "$target/$_json" ]; then
      continue
    fi
    if ! jq empty "$target/$_json" 2>/dev/null; then
      echo "scaffold_error=invalid_json file=$_json"
      exit 1
    fi
    if [ -n "$SIBLING_DIR" ] && [ "$SIBLING_DIR" != "$MODULE_DIR" ]; then
      sed -i.bak "s/$SIBLING_DIR/$MODULE_DIR/g" "$target/$_json" 2>/dev/null || true
      rm -f "$target/$_json.bak"
      if ! jq empty "$target/$_json" 2>/dev/null; then
        echo "scaffold_error=invalid_json_after_rename file=$_json"
        exit 1
      fi
    fi
  done

  local primary_tf=""
  local _f _base
  for _f in "$target"/*.tf; do
    _base="$(basename "$_f")"
    if [ "$_base" = "provider.tf" ] || [ "$_base" = "versions.tf" ]; then
      continue
    fi
    primary_tf="$_f"
    break
  done
  if [ -n "$primary_tf" ] && [ "$(basename "$primary_tf")" = "${SIBLING_DIR}.tf" ]; then
    mv "$primary_tf" "$target/${MODULE_DIR}.tf"
  fi

  local mock_provider="aws"
  [ "$PROVIDER_ROOT" = "gcp" ] && mock_provider="google"
  [ "$PROVIDER_ROOT" = "azurerm" ] && mock_provider="azurerm"

  cat >"$target/basic.tftest.hcl" <<EOF
mock_provider "$mock_provider" {}

# Plan-only smoke test; no assert with literal true (OpenTofu rejects non-referential conditions).
run "basic_plan" {
  command = plan
}
EOF

  mirror_note "$work_root" "discovery_provider" "$PROVIDER_ROOT"
  mirror_note "$work_root" "discovery_module_dir" "$MODULE_DIR"
  echo "discovery_provider=$PROVIDER_ROOT"
  echo "discovery_module_dir=$MODULE_DIR"
  discovery_scaffold_finalize_with_validate "$work_root" "$target" "greenfield" "copied_sibling=$(basename "$sibling")"
}

cmd_discovery_check() {
  local work_root="${1:?WORK_ROOT}"
  local repo_clone="${2:?REPO_CLONE_PATH}"
  local provider="${3:?PROVIDER}"
  local module_dir="${4:?MODULE_DIR}"

  repo_clone="$(resolve_repo_dir "$work_root")"
  mirror_note "$work_root" "repo_clone_path" "$repo_clone"

  local candidate="$repo_clone/$provider/$module_dir"
  local confidence="not_found"
  local module_path=""

  if [ -d "$candidate" ] && [ -n "$(find "$candidate" -maxdepth 1 -name '*.tf' -print -quit 2>/dev/null)" ]; then
    confidence="exact"
    module_path="$candidate"
  else
    dupes=()
    while IFS= read -r _dupe; do
      dupes+=("$_dupe")
      if [ "${#dupes[@]}" -ge 5 ]; then
        break
      fi
    done < <(find "$repo_clone/$provider" -type d -name "$module_dir" 2>/dev/null)
    if [ "${#dupes[@]}" -eq 1 ]; then
      confidence="exact"
      module_path="${dupes[0]}"
    elif [ "${#dupes[@]}" -gt 1 ]; then
      confidence="ambiguous"
      module_path="$(printf '%s,' "${dupes[@]}" | sed 's/,$//')"
    fi
  fi

  local stackgen_provider="$provider"
  [ "$provider" = "azurerm" ] && stackgen_provider="azure"

  mirror_note "$work_root" "discovery_provider" "$provider"
  mirror_note "$work_root" "discovery_module_dir" "$module_dir"
  mirror_note "$work_root" "discovery_stackgen_provider" "$stackgen_provider"
  mirror_note "$work_root" "module_resolution_confidence" "$confidence"
  [ -n "$module_path" ] && mirror_note "$work_root" "module_paths" "$module_path"

  echo "module_resolution_confidence=$confidence"
  echo "module_paths=$module_path"
  echo "discovery_provider=$provider"
  echo "discovery_module_dir=$module_dir"
}

require_embedded_invocation || exit 1

cmd="${1:?command required}"
shift
case "$cmd" in
  clone) cmd_clone "$@" ;;
  validate) cmd_validate "$@" ;;
  validate-and-pr) cmd_validate_and_pr "$@" ;;
  commit-pr) cmd_commit_pr "$@" ;;
  resolve-paths) cmd_resolve_paths "$@" ;;
  discovery-check) cmd_discovery_check "$@" ;;
  discovery-scaffold) cmd_discovery_scaffold "$@" ;;
  *)
    echo "unknown_command=$cmd"
    exit 1
    ;;
esac
