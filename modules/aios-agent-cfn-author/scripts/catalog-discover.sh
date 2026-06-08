#!/usr/bin/env bash
# catalog-discover.sh — keyword-match catalog templates; writes catalog_candidates.json.
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-}"
SPEC="${WORK_ROOT}/requirements_spec.json"
OUT="${WORK_ROOT}/generated/catalog_candidates.json"
CATALOG_PATH="${CFN_AUTHOR_CATALOG_PATH:-cloudformation/catalog/}"
CATALOG_REPO="${CATALOG_REPO:-}"
REPO_FULL_NAME="${REPO_FULL_NAME:-${CFN_AUTHOR_DEFAULT_REPO:-}}"
FIXTURE_DIR="${CATALOG_DISCOVER_FIXTURE_DIR:-}"

if [[ -z "${WORK_ROOT}" ]]; then
  echo "catalog_discover_complete=false"
  echo "catalog_discover_blocked=missing_work_root"
  exit 1
fi

mkdir -p "${WORK_ROOT}/generated"

if [[ ! -f "${SPEC}" ]] || ! command -v jq >/dev/null 2>&1; then
  echo '[]' > "${OUT}"
  echo "catalog_discover_complete=true"
  echo "catalog_candidate_count=0"
  exit 0
fi

intent="$(jq -r '.intent // ""' "${SPEC}" | tr '[:upper:]' '[:lower:]')"
stack_name="$(jq -r '.stack_name // ""' "${SPEC}" | tr '[:upper:]' '[:lower:]')"
catalog_repo="$(jq -r '.catalog_repo // empty' "${SPEC}")"
if [[ -n "${catalog_repo}" && "${catalog_repo}" != "null" ]]; then
  CATALOG_REPO="${catalog_repo}"
fi
if [[ -z "${CATALOG_REPO}" ]]; then
  CATALOG_REPO="${REPO_FULL_NAME}"
fi

keywords=()
for token in s3 rds vpc lambda ecs eks aurora redis cache dynamodb alb nlb cloudfront; do
  if printf '%s %s' "${intent}" "${stack_name}" | grep -qi "${token}"; then
    keywords+=("${token}")
  fi
done

search_root=""
if [[ -n "${FIXTURE_DIR}" && -d "${FIXTURE_DIR}" ]]; then
  search_root="${FIXTURE_DIR}"
elif [[ -d "${WORK_ROOT}/repo/${CATALOG_PATH}" ]]; then
  search_root="${WORK_ROOT}/repo/${CATALOG_PATH}"
elif [[ -d "${WORK_ROOT}/catalog-fixture/${CATALOG_PATH}" ]]; then
  search_root="${WORK_ROOT}/catalog-fixture/${CATALOG_PATH}"
fi

candidates=()
if [[ -n "${search_root}" ]]; then
  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    rel="${file#${search_root}/}"
    base="$(basename "${file}" .yaml)"
    base="$(basename "${base}" .yml)"
    base_lc="$(printf '%s' "${base}" | tr '[:upper:]' '[:lower:]')"
    score=1
    for kw in "${keywords[@]}"; do
      if printf '%s' "${base_lc} ${rel}" | grep -qi "${kw}"; then
        score=$((score + 2))
      fi
    done
    if [[ "${score}" -le 1 && ${#keywords[@]} -gt 0 ]]; then
      continue
    fi
    rationale="Catalog file matches intent keywords"
    if [[ ${#keywords[@]} -gt 0 ]]; then
      rationale="Matches keywords: ${keywords[*]}"
    fi
    candidates+=("$(jq -nc --arg path "${CATALOG_PATH%/}/${rel}" --argjson score "${score}" --arg rationale "${rationale}" \
      '{path: $path, score: $score, rationale: $rationale}')")
  done < <(find "${search_root}" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) 2>/dev/null | head -50)
fi

if [[ ${#candidates[@]} -eq 0 ]]; then
  echo '[]' > "${OUT}"
  echo "catalog_discover_complete=true"
  echo "catalog_candidate_count=0"
  exit 0
fi

printf '%s\n' "${candidates[@]}" | jq -s 'sort_by(-.score) | .[0:5]' > "${OUT}"
count="$(jq 'length' "${OUT}")"
echo "catalog_discover_complete=true"
echo "catalog_candidate_count=${count}"
echo "catalog_candidates_path=${OUT}"
