#!/usr/bin/env bash
# read-script-pack-version.sh — print script_pack_version from main.tf (used by CI and smoke tests).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"
PACK_VERSION="$(grep -E 'script_pack_version[[:space:]]*=' "$MAIN" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [[ -z "${PACK_VERSION}" ]]; then
  echo "FAIL: could not read script_pack_version from ${MAIN}" >&2
  exit 1
fi
echo "${PACK_VERSION}"
