#!/usr/bin/env bash
# Print or run the spec-symphony remote runner docker command from tofu output.
set -euo pipefail

SCENARIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN=0

if [ "${1:-}" = "--run" ]; then
  RUN=1
fi

tf() {
  if command -v tofu >/dev/null 2>&1; then tofu "$@"; else terraform "$@"; fi
}

cmd="$(cd "$SCENARIO_DIR" && tf output -raw remote_runner_docker_run_command 2>/dev/null || true)"
if [ -z "$cmd" ] || [ "$cmd" = "null" ]; then
  echo "error: remote_runner_docker_run_command empty — tofu apply first" >&2
  exit 1
fi

echo "$cmd"
if [ "$RUN" -eq 1 ]; then
  echo "==> starting runner container" >&2
  eval "$cmd"
  echo "==> waiting for aiden-runner to connect (up to 60s)" >&2
  deadline=$((SECONDS + 60))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if docker logs spec-symphony-runner 2>&1 | tail -30 | grep -qiE 'connected|registered|ready|listening'; then
      echo "==> runner appears connected" >&2
      sleep 5
      break
    fi
    sleep 3
  done
fi
