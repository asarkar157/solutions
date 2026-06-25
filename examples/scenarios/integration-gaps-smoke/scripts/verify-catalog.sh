#!/usr/bin/env bash
# verify-catalog.sh — assert Guild catalog lists all nine gap integration types.
set -euo pipefail

GUILD_URL="${GUILD_URL:-http://localhost:8088}"
EXPECTED_TYPES=(
  kubernetes sonarqube firehydrant digitalocean coralogix
  civo newrelic circleci squadcast
)

AUTH_HEADER="${AUTH_HEADER:-}"
if [[ -z "${AUTH_HEADER}" && -n "${STACKGEN_TOKEN:-}" ]]; then
  AUTH_HEADER="Authorization: Bearer ${STACKGEN_TOKEN}"
fi

CURL_AUTH=()
if [[ -n "${AUTH_HEADER}" ]]; then
  CURL_AUTH=(-H "${AUTH_HEADER}")
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "$1 required" >&2; exit 1; }; }
need curl
need jq

url="${GUILD_URL%/}/guild/api/v1/integrations/types"
body="$(curl -sS "${CURL_AUTH[@]}" "${url}")"
types="$(echo "${body}" | jq -r '.[].type' | sort)"

missing=0
for t in "${EXPECTED_TYPES[@]}"; do
  if ! echo "${types}" | grep -qx "${t}"; then
    echo "MISSING catalog type: ${t}" >&2
    missing=$((missing + 1))
  fi
done

count="$(echo "${body}" | jq 'length')"
echo "Catalog reports ${count} integration types"
if [[ "${missing}" -gt 0 ]]; then
  exit 1
fi
echo "All nine gap types present in catalog."
