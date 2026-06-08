#!/usr/bin/env bash
# commit-openslo-pr.sh — clone OpenSLO repo, copy draft YAML from WORK_ROOT, open PR.
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-${1:-}}"
REPO_FULL_NAME="${REPO_FULL_NAME:-${2:-}}"
BASE_BRANCH="${BASE_BRANCH:-main}"
OPENSLO_PATH_PREFIX="${OPENSLO_PATH_PREFIX:-openslo/}"
PR_TITLE="${PR_TITLE:-}"
PR_BODY="${PR_BODY:-}"
BRANCH_PREFIX="${BRANCH_PREFIX:-aiden/slo}"
DRAFT_MANIFEST="${WORK_ROOT}/draft_files.json"
GIT_USER_NAME="${GIT_USER_NAME:-stackgen-slo-health}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-slo-health@stackgen.local}"

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

if [[ -z "${PR_TITLE}" ]]; then
  PR_TITLE="feat(openslo): SLO definitions from Guild slo-health workflow"
fi

REPO_DIR="${WORK_ROOT}/repo"
mkdir -p "${WORK_ROOT}"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  if ! gh repo clone "${REPO_FULL_NAME}" "${REPO_DIR}" -- --branch "${BASE_BRANCH}" >/dev/null; then
    echo "clone_blocker=auth_or_network"
    exit 1
  fi
fi

cd "${REPO_DIR}"
if ! bootstrap_git_auth; then
  exit 1
fi

if ! git fetch origin "${BASE_BRANCH}" 2>/dev/null; then
  echo "fetch_blocker=auth_or_network"
  exit 1
fi
git checkout "${BASE_BRANCH}" 2>/dev/null || git checkout -b "${BASE_BRANCH}" "origin/${BASE_BRANCH}"
git reset --hard "origin/${BASE_BRANCH}"
BRANCH="${BRANCH_PREFIX}-$(date +%Y%m%d%H%M%S)-$$"
git checkout -b "${BRANCH}"

DRAFT_ROOT="${WORK_ROOT}/openslo-drafts"
if [[ ! -d "${DRAFT_ROOT}" ]]; then
  echo "pr_blocker=missing_draft_root"
  exit 1
fi

copy_draft_rel() {
  local rel="$1"
  local src="${DRAFT_ROOT}/${rel}"
  local dest="${OPENSLO_PATH_PREFIX%/}/${rel}"
  if [[ ! -f "${src}" ]]; then
    return 1
  fi
  mkdir -p "$(dirname "${dest}")"
  cp "${src}" "${dest}"
  return 0
}

copied=0
if [[ -f "${DRAFT_MANIFEST}" ]] && command -v jq >/dev/null 2>&1; then
  while IFS= read -r rel; do
    [[ -z "${rel}" ]] && continue
    if copy_draft_rel "${rel}"; then
      copied=$((copied + 1))
    fi
  done < <(jq -r '.files[].path // empty' "${DRAFT_MANIFEST}")
fi

if [[ "${copied}" -eq 0 ]]; then
  while IFS= read -r -d '' f; do
    rel="${f#${DRAFT_ROOT}/}"
    if copy_draft_rel "${rel}"; then
      copied=$((copied + 1))
    fi
  done < <(find "${DRAFT_ROOT}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0)
fi

if [[ "${copied}" -eq 0 ]]; then
  echo "pr_blocker=no_draft_files"
  exit 1
fi

git add -A
if git diff --cached --quiet; then
  echo "pr_blocker=no_changes_to_commit"
  exit 1
fi

git commit -m "${PR_TITLE}"

if ! git push -u origin "${BRANCH}" >/dev/null; then
  echo "pr_blocker=push_failed"
  exit 1
fi

BODY_FILE="${WORK_ROOT}/pr-body.md"
if [[ -n "${PR_BODY}" ]]; then
  printf '%s\n' "${PR_BODY}" > "${BODY_FILE}"
else
  cat > "${BODY_FILE}" <<EOF
## SLO definitions (Guild slo-health)

Automated OpenSLO YAML from Grafana signal discovery / drift reconcile.

Files changed: ${copied}

Review PromQL and objectives before merge. Deploy Sloth recording rules after merge if not already present.
EOF
fi

PR_ERR_FILE="${WORK_ROOT}/pr-create.err"
if pr_url="$(gh pr create --base "${BASE_BRANCH}" --head "${BRANCH}" --title "${PR_TITLE}" --body-file "${BODY_FILE}" 2>"${PR_ERR_FILE}")"; then
  if [[ ! "${pr_url}" =~ ^https:// ]]; then
    echo "pr_blocker=pr_creation_failed"
    exit 1
  fi
  echo "pr_url=${pr_url}"
  echo "files_committed=${copied}"
  exit 0
fi

if grep -qi "already exists" "${PR_ERR_FILE}" 2>/dev/null; then
  existing="$(gh pr list --head "${BRANCH}" --json url -q '.[0].url' 2>/dev/null || true)"
  if [[ -n "${existing}" ]]; then
    echo "pr_url=${existing}"
    exit 0
  fi
fi

echo "pr_blocker=gh_pr_create_failed"
exit 1
