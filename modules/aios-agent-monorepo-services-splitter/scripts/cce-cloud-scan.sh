#!/usr/bin/env bash
# Deprecated: use monorepo-cce-scan.sh. Retained for script-pack backward compatibility.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

if [ -f "${SCRIPT_DIR}/monorepo-cce-scan.sh" ]; then
  exec bash "${SCRIPT_DIR}/monorepo-cce-scan.sh" "$@"
fi

echo "usage: cce-cloud-scan.sh scan REPO_ROOT LANGUAGES_JSON (deprecated)" >&2
exit 1
