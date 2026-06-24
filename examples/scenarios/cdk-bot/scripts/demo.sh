#!/usr/bin/env bash
# Quick pointer — full story: ../README.md
set -euo pipefail
cat <<'EOF'
CDK bot demo — see examples/scenarios/cdk-bot/README.md

Order of operations:
  1. tofu apply
  2. ./scripts/start-runner.sh --run          # keep running
  3. Trigger ONE of:
       Brownfield (first):  ./scripts/trigger-webhook.sh --from-tofu-output --create-github-issue ...
       Greenfield (G1):     ./scripts/trigger-greenfield-g1.sh --repo OWNER/cdk-typescript-demo

Success on GitHub: progress comment → module_quality_summary=PASS → draft PR link

Script-pack only (no LLM):
  ./scripts/local-run-t2.sh   # brownfield KMS
  ./scripts/local-run-g1.sh   # greenfield files

Test matrix: modules/aios-agent-cdk-bot/docs/workflow-test-inputs.md
EOF
