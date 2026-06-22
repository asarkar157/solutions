#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "${ROOT}/tests/workflow_structure_test.sh"
bash "${ROOT}/tests/stage_runner_logic_test.sh"
bash "${ROOT}/tests/test_clone_execute_guard.sh"
bash "${ROOT}/tests/script_pack_ensure_test.sh"
echo "OK: verify-cdk-bot-workflow-scripts"
