#!/usr/bin/env bash
# commit-and-pr.sh — clone target repo, write template, push branch, open PR.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="${WORK_ROOT:-${1:-}}"
REPO_FULL_NAME="${REPO_FULL_NAME:-${2:-}}"
BASE_BRANCH="${BASE_BRANCH:-main}"
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-cloudformation/}"
TEMPLATE_FILE="${TEMPLATE_FILE:-template.yaml}"
PR_TITLE="${PR_TITLE:-}"
GIT_USER_NAME="${GIT_USER_NAME:-stackgen-cfn-author}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-cfn-author@stackgen.local}"

# resolve_target_path computes the repo-relative template path without duplicating TEMPLATE_PREFIX.
resolve_target_path() {
  local prefix="${1:-}"
  local file="${2:-template.yaml}"
  local stack="${3:-stack}"
  prefix="${prefix%/}"
  file="${file#/}"
  if [[ -z "${file}" || "${file}" == "template.yaml" ]]; then
    if [[ -n "${stack}" && "${stack}" != "stack" ]]; then
      file="${stack}/template.yaml"
    else
      file="template.yaml"
    fi
  fi
  if [[ -n "${prefix}" && "${file}" == "${prefix}/"* ]]; then
    printf '%s\n' "${file}"
    return
  fi
  if [[ -n "${prefix}" ]]; then
    printf '%s/%s\n' "${prefix}" "${file}"
    return
  fi
  printf '%s\n' "${file}"
}

bootstrap_git_auth() {
  local git_token="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
  export GIT_TOKEN="$git_token" GH_TOKEN="$git_token" GITHUB_TOKEN="$git_token"
  export GIT_TERMINAL_PROMPT=0
  if [[ -z "$git_token" ]]; then
    echo "pr_blocker=missing_git_auth"
    return 1
  fi
  gh auth setup-git
  git config --global user.name "${GIT_USER_NAME}"
  git config --global user.email "${GIT_USER_EMAIL}"
}

if [[ -z "${WORK_ROOT}" || -z "${REPO_FULL_NAME}" ]]; then
  echo "pr_blocker=missing_repo_or_work_root"
  exit 1
fi

if ! bash "${SCRIPT_DIR}/governed-deployment-check.sh"; then
  exit 1
fi

REQ_SPEC="${WORK_ROOT}/requirements_spec.json"
if [[ -f "${REQ_SPEC}" ]] && command -v jq >/dev/null 2>&1; then
  STACK_NAME="${STACK_NAME:-$(jq -r '.stack_name // empty' "${REQ_SPEC}")}"
  ENVIRONMENT="${ENVIRONMENT:-$(jq -r '.environment // empty' "${REQ_SPEC}")}"
  INTENT="${INTENT:-$(jq -r '.intent // .request // .description // empty' "${REQ_SPEC}")}"
  AWS_REGION="${AWS_REGION:-$(jq -r '.region // .aws_region // empty' "${REQ_SPEC}")}"
  spec_template="$(jq -r '.template_file_name // .template_output_path // empty' "${REQ_SPEC}")"
  if [[ -n "${spec_template}" && "${spec_template}" != "null" ]]; then
    TEMPLATE_FILE="${spec_template}"
  elif [[ -n "${STACK_NAME}" ]]; then
    TEMPLATE_FILE="${STACK_NAME}/template.yaml"
  fi
  path_prefix_from_spec="$(jq -r '.path_prefix // empty' "${REQ_SPEC}")"
  if [[ -n "${path_prefix_from_spec}" ]]; then
    TEMPLATE_PREFIX="${path_prefix_from_spec}"
  fi
fi

STACK_NAME="${STACK_NAME:-stack}"
ENVIRONMENT="${ENVIRONMENT:-unknown}"
INTENT="${INTENT:-CloudFormation template generated from developer intent.}"
AWS_REGION="${AWS_REGION:-us-east-1}"

if [[ -z "${PR_TITLE}" ]]; then
  PR_TITLE="feat(cloudformation): Add ${STACK_NAME} stack (${ENVIRONMENT})"
fi

REPO_DIR="${WORK_ROOT}/repo"
mkdir -p "${WORK_ROOT}"
if [[ ! -d "${REPO_DIR}/.git" ]]; then
  if ! gh repo clone "${REPO_FULL_NAME}" "${REPO_DIR}" -- --branch "${BASE_BRANCH}" 2>&1; then
    echo "clone_blocker=auth_or_network"
    exit 1
  fi
fi

cd "${REPO_DIR}"
if ! bootstrap_git_auth; then
  exit 1
fi

if ! git fetch origin "${BASE_BRANCH}" 2>&1; then
  echo "fetch_blocker=auth_or_network"
  exit 1
fi
git checkout "${BASE_BRANCH}" 2>/dev/null || git checkout -b "${BASE_BRANCH}" "origin/${BASE_BRANCH}"
git reset --hard "origin/${BASE_BRANCH}"
BRANCH="cfn-author/$(date +%Y%m%d%H%M%S)-$$"
git checkout -b "${BRANCH}"

TARGET_PATH="$(resolve_target_path "${TEMPLATE_PREFIX}" "${TEMPLATE_FILE}" "${STACK_NAME}")"
mkdir -p "$(dirname "${TARGET_PATH}")"
if [[ -n "${TEMPLATE_BODY_FILE:-}" && -f "${TEMPLATE_BODY_FILE}" ]]; then
  cp "${TEMPLATE_BODY_FILE}" "${TARGET_PATH}"
else
  echo "pr_blocker=missing_template_body"
  exit 1
fi

# Always render PR body in-script. LLM or shell-exported PR_BODY is ignored (avoids JSON-escaped markdown in gh).
unset PR_BODY
ARCH_FINDINGS="${WORK_ROOT}/generated/architecture-findings.json"
architecture_section=""
if [[ -f "${ARCH_FINDINGS}" ]] && command -v jq >/dev/null 2>&1; then
  arch_summary="$(jq -r '.architecture_summary // empty' "${ARCH_FINDINGS}")"
  if [[ -n "${arch_summary}" && "${arch_summary}" != "PASS" ]]; then
    architecture_section="$(mktemp)"
    {
      echo ""
      echo "## Architecture review"
      echo ""
      echo "**Status:** ${arch_summary}"
      echo ""
      jq -r '.findings[] | "- **\(.id)** (\(.severity)): \(.message)"' "${ARCH_FINDINGS}" 2>/dev/null || true
      echo ""
      if [[ "${arch_summary}" == "NEEDS_REVIEW" ]]; then
        echo "> Resolve or accept findings before promoting to production."
      fi
    } > "${architecture_section}"
  fi
fi

PR_BODY="$(cat <<EOF
## Summary

This change adds a production-oriented CloudFormation template for **${STACK_NAME}** in the **${ENVIRONMENT}** environment.

## Intent

${INTENT}

## Template details

| Field | Value |
|-------|-------|
| Path | \`${TARGET_PATH}\` |
| Region | ${AWS_REGION} |
| Stack name (target) | \`${STACK_NAME}\` |

## Validation

- Template synthesized against org catalog patterns and passed **cfn-lint** / **validate-template** checks in the cfn-author pipeline.
- Security guardrails (Checkov / cfn-nag) were evaluated before this PR was opened.
- Architecture-fit lint ran post-synthesis against declared NFRs (RPS, FedRAMP, scaling metrics).

## Deployment guidance

1. Review IAM actions, resource naming, encryption, and public-access settings before merge.
2. Create a change set against \`${STACK_NAME}\` in **${AWS_REGION}**; inspect resource additions and IAM policy changes.
3. Execute only through your standard promotion pipeline — do not apply directly from a feature branch without review.

## Rollback

Retain the previous template revision on \`${BASE_BRANCH}\`; rollback is a revert of this commit followed by a controlled stack update.

---
*Authored via StackGen cfn-author intent-to-infrastructure workflow.*
EOF
)"
if [[ -n "${architecture_section}" && -f "${architecture_section}" ]]; then
  PR_BODY="${PR_BODY}"$'\n'"$(cat "${architecture_section}")"
  rm -f "${architecture_section}"
fi

git add "${TARGET_PATH}"
if git diff --cached --quiet; then
  echo "pr_blocker=no_template_changes"
  exit 1
fi

if ! git commit -m "${PR_TITLE}"; then
  echo "pr_blocker=commit_failed"
  exit 1
fi

if ! git push -u origin "${BRANCH}"; then
  echo "pr_blocker=push_auth"
  exit 1
fi

PR_BODY_FILE="${WORK_ROOT}/pr-body.md"
printf '%s\n' "${PR_BODY}" > "${PR_BODY_FILE}"

PR_URL="$(gh pr create --base "${BASE_BRANCH}" --head "${BRANCH}" --title "${PR_TITLE}" --body-file "${PR_BODY_FILE}")"
if [[ ! "${PR_URL}" =~ ^https:// ]]; then
  echo "pr_blocker=pr_creation_failed"
  exit 1
fi
printf '%s\n' "${PR_URL}" > "${WORK_ROOT}/pr_url.txt"
echo "pr_url=${PR_URL}"
echo "working_branch=${BRANCH}"
echo "template_path=${TARGET_PATH}"
