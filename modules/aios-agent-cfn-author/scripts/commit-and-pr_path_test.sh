#!/usr/bin/env bash
# commit-and-pr_path_test.sh — verify TARGET_PATH resolution without duplicate prefix.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

path="$(resolve_target_path "cloudformation/" "cloudformation/staging-data/template.yaml" "staging-data")"
[[ "${path}" == "cloudformation/staging-data/template.yaml" ]] || {
  echo "FAIL: expected single prefix, got ${path}" >&2
  exit 1
}

path="$(resolve_target_path "cloudformation/" "template.yaml" "staging-data")"
[[ "${path}" == "cloudformation/staging-data/template.yaml" ]] || {
  echo "FAIL: expected stack default path, got ${path}" >&2
  exit 1
}

echo "OK: commit-and-pr path resolution"
