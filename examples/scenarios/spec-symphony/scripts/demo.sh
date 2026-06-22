#!/usr/bin/env bash
# Spec-symphony scenario — quick test guide (prints commands; does not apply).
set -euo pipefail

cat <<'EOF'
Spec-symphony test flow
=======================

1) Apply scenario (from repo root):
   export STACKGEN_URL=https://ai.dev.stackgen.com
   export STACKGEN_TOKEN=...
   export GITHUB_TOKEN=...          # repo scope for runner + optional gh issue create
   export OPENAI_API_KEY=...        # or ANTHROPIC / GEMINI
   make demo SCENARIO=spec-symphony

   Or manually:
   cd examples/scenarios/spec-symphony
   cp terraform.tfvars.example terraform.tfvars   # edit target_repository_full_name
   tofu init && tofu apply

2) Start remote runner (requires Docker):
   ./scripts/start-runner.sh
   ./scripts/start-runner.sh --run    # execute docker run

3) Trigger workflow via webhook:
   ./scripts/trigger-webhook.sh --from-tofu-output \
     --create-github-issue \
     --repo YOUR_ORG/YOUR_REPO \
     --title "CORE-101 Add health check endpoint" \
     --body "Add GET /health returning 200. Bootstrap OpenSpec if missing."

4) Watch Guild UI for workflow spec-driven-feature run.

Test matrix
-----------
| Case | sdd_framework | change_type | Repo hint |
|------|---------------|-------------|-----------|
| T1 greenfield TS | spec-kit | greenfield | empty repo or new service |
| T2 brownfield | openspec | brownfield | existing app with openspec/ |
| T3 auto | auto | bugfix | mixed — auto-detect |

Skip docker build on apply host (image already built):
  build_runner_image = false

EOF
