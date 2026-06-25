#!/usr/bin/env bash
# test-integrations.sh — Guild MCP smoke test for Aiden-2 gap integration types.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GUILD_URL="${GUILD_URL:-http://localhost:8088}"
MIN_DISCOVERED="${MIN_DISCOVERED:-1}"

AUTH_HEADER="${AUTH_HEADER:-}"
if [[ -z "${AUTH_HEADER}" && -n "${STACKGEN_TOKEN:-}" ]]; then
  AUTH_HEADER="Authorization: Bearer ${STACKGEN_TOKEN}"
fi

CURL_AUTH=()
if [[ -n "${AUTH_HEADER}" ]]; then
  CURL_AUTH=(-H "${AUTH_HEADER}")
fi

cd "${SCENARIO_DIR}"
need() { command -v "$1" >/dev/null 2>&1 || { echo "$1 required" >&2; exit 1; }; }
need tofu
need jq
need curl

mapfile -t NAMES < <(tofu output -json integration_names 2>/dev/null | jq -r '.[]' || true)
if [[ ${#NAMES[@]} -eq 0 ]]; then
  echo "No integration names from tofu output; enable integrations in tfvars and run tofu apply." >&2
  exit 1
fi

BASE="${GUILD_URL%/}/guild/api/v1/integrations"
PASS=0
FAIL=0

for name in "${NAMES[@]}"; do
  echo ""
  echo "── ${name} ──"
  resp="$(curl -sS -w "\n%{http_code}" -X POST "${CURL_AUTH[@]}" "${BASE}/${name}/test" \
    -H "Content-Type: application/json" -d '{}' 2>/dev/null || printf '\n000')"
  body="$(echo "${resp}" | sed '$d')"
  code="$(echo "${resp}" | tail -n1)"

  if [[ "${code}" != "200" ]]; then
    echo "  FAIL: HTTP ${code}"
    echo "${body}" | head -c 400
    FAIL=$((FAIL + 1))
    continue
  fi

  success="$(echo "${body}" | jq -r '.success // false')"
  tool_count="$(echo "${body}" | jq '.discovered_tools | length' 2>/dev/null || echo 0)"
  msg="$(echo "${body}" | jq -r '.message // ""' 2>/dev/null | head -c 200)"

  if [[ "${success}" == "true" && "${tool_count}" -ge "${MIN_DISCOVERED}" ]]; then
    sample="$(echo "${body}" | jq -r '[.discovered_tools[]?.name][0:5] | join(", ")')"
    echo "  PASS: ${tool_count} tools (${sample})"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${msg:-success=${success}, tools=${tool_count}}"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Summary: ${PASS} passed, ${FAIL} failed (of ${#NAMES[@]})"
[[ "${FAIL}" -eq 0 ]]
