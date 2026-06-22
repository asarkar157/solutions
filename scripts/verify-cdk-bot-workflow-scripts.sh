#!/usr/bin/env bash
# Smoke-check cdk-bot workflow script pack and spawn contract guards.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="${ROOT}/modules/aios-agent-cdk-bot"

bash "${MOD}/scripts/verify-cdk-bot-workflow-scripts.sh"
echo "verify-cdk-bot-workflow-scripts: OK"
