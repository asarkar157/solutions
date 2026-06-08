#!/usr/bin/env bash
# policy-scan.sh — backward-compatible alias for security-guardrails.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/security-guardrails.sh"
