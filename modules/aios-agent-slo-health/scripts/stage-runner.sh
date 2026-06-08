#!/usr/bin/env bash
# stage-runner.sh — dispatch commit-openslo-pr for slo-health module.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
  commit-openslo-pr)
    exec "${SCRIPT_DIR}/commit-openslo-pr.sh"
    ;;
  write-openslo-drafts)
    exec "${SCRIPT_DIR}/write-openslo-drafts.sh"
    ;;
  *)
    echo "usage: stage-runner.sh commit-openslo-pr|write-openslo-drafts" >&2
    exit 1
    ;;
esac
