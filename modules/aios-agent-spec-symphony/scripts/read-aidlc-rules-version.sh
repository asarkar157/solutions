#!/usr/bin/env bash
# read-aidlc-rules-version.sh — print aidlc_rules_version default from variables.tf (CI Docker build).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VARS="${ROOT}/variables.tf"
VERSION="$(awk '/variable "aidlc_rules_version"/,/^[}]/' "$VARS" | grep -E '^\s*default\s*=' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [[ -z "${VERSION}" ]]; then
  echo "FAIL: could not read aidlc_rules_version default from ${VARS}" >&2
  exit 1
fi
echo "${VERSION}"
