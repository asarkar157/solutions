#!/usr/bin/env bash
# Self-contained terraform-bot stage runner — embed via heredoc in ONE execute_series.
# Ubuntu MCP container may reset between separate tool calls; all clone/write/validate for a subagent must stay in one series.
# Usage: bash -s <command> [args...] << 'TFBOT_STAGE_RUNNER' ... TFBOT_STAGE_RUNNER
# Commands: clone | validate | commit-pr | resolve-paths | discovery-check
set -euo pipefail

mirror_note() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  local value="${3:?VALUE}"
  local notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"
  jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$notes" >"${notes}.tmp" \
    && mv "${notes}.tmp" "$notes"
  echo "mirrored:${key}"
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
    return 1
  fi

  local tf_version fmt_rc=0 init_rc=0 valid_rc=0 test_rc=0
  tf_version="$("$tf" version | head -1)"

  "$tf" fmt -recursive -check >"$work_dir/tf-fmt.out" 2>&1 || fmt_rc=$?
  "$tf" init -backend=false -input=false >"$work_dir/tf-init.out" 2>&1 || init_rc=$?
  "$tf" validate -no-color >"$work_dir/tf-validate.out" 2>&1 || valid_rc=$?

  if command -v tfsec >/dev/null 2>&1; then
    tfsec --no-color --soft-fail --format json . >"$work_dir/tfsec.json" 2>&1 || true
  else
    echo "tfsec_not_found=true" >"$work_dir/tfsec.json"
  fi

  if command -v checkov >/dev/null 2>&1; then
    checkov -d . --quiet --soft-fail --output json --output-file-path "$work_dir/checkov.json" >/dev/null 2>&1 || true
  else
    echo "checkov_not_found=true" >"$work_dir/checkov.json"
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
  prev_summary="$(note_val "$work_root" module_quality_summary)"
  if [ "$this_pass" = "NEEDS_REVISION" ] || [ "$prev_summary" = "NEEDS_REVISION" ]; then
    mirror_note "$work_root" "module_quality_summary" "NEEDS_REVISION"
  else
    mirror_note "$work_root" "module_quality_summary" "PASS"
  fi

  echo "$summary"
  echo "module_quality_summary=$([ "$fmt_rc" -eq 0 ] && [ "$valid_rc" -eq 0 ] && [ "$test_rc" -eq 0 ] && echo PASS || echo NEEDS_REVISION)"
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

  local repo_dir="$work_root/repo"
  if [ ! -d "$repo_dir/.git" ]; then
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

  branch="$(branch_slug_from_module "$module_relpath")"
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

  local pr_url=""
  pr_url="$(gh pr list --repo "$repo_full_name" --head "$branch" --json url -q '.[0].url' 2>/dev/null || true)"
  if [ -z "$pr_url" ] || [ "$pr_url" = "null" ]; then
    pr_url="$(gh pr create --repo "$repo_full_name" --base "$base_branch" --head "$branch" \
      --title "$pr_title" --body-file "$pr_body_file")"
  fi

  mirror_note "$work_root" "working_branch" "$branch"
  mirror_note "$work_root" "pr_url" "$pr_url"
  mirror_note "$work_root" "pr_title" "$pr_title"
  mirror_note "$work_root" "pr_deferred" "false"
  echo "working_branch=$branch"
  echo "pr_url=$pr_url"
  echo "pr_title=$pr_title"
}

cmd_resolve_paths() {
  local work_root="${1:?WORK_ROOT}"
  local repo_clone="${2:?REPO_CLONE_PATH}"
  local default_branch="${3:?DEFAULT_BRANCH}"
  local hint_csv="${4:-}"

  [ -f "$work_root/notes.json" ] || echo '{}' >"$work_root/notes.json"
  [ -n "$hint_csv" ] && mirror_note "$work_root" "target_module_hints" "$hint_csv"

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

cmd_discovery_check() {
  local work_root="${1:?WORK_ROOT}"
  local repo_clone="${2:?REPO_CLONE_PATH}"
  local provider="${3:?PROVIDER}"
  local module_dir="${4:?MODULE_DIR}"

  local candidate="$repo_clone/$provider/$module_dir"
  local confidence="not_found"
  local module_path=""

  if [ -d "$candidate" ] && [ -n "$(find "$candidate" -maxdepth 1 -name '*.tf' -print -quit 2>/dev/null)" ]; then
    confidence="exact"
    module_path="$candidate"
  else
    mapfile -t dupes < <(
      find "$repo_clone/$provider" -type d -name "$module_dir" 2>/dev/null | head -5
    )
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

cmd="${1:?command required}"
shift
case "$cmd" in
  clone) cmd_clone "$@" ;;
  validate) cmd_validate "$@" ;;
  commit-pr) cmd_commit_pr "$@" ;;
  resolve-paths) cmd_resolve_paths "$@" ;;
  discovery-check) cmd_discovery_check "$@" ;;
  *)
    echo "unknown_command=$cmd"
    exit 1
    ;;
esac
