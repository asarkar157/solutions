#!/usr/bin/env bash
# Headless Cursor Agent CLI on the remote runner (repo-local).
set -euo pipefail

REPO_DIR="${1:?repo_dir}"
PROMPT="${2:?prompt}"

if [ -z "${CURSOR_API_KEY:-}" ]; then
  echo "cursor_blocker=missing_cursor_api_key"
  exit 1
fi

if ! command -v agent >/dev/null 2>&1; then
  echo "cursor_blocker=agent_cli_not_installed"
  exit 1
fi

cd "$REPO_DIR"
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

if ! agent -p --trust --yolo --output-format json "$PROMPT" >"$out" 2>&1; then
  echo "cursor_blocker=agent_exit_nonzero"
  tail -n 40 "$out" >&2 || true
  exit 1
fi

if git diff --quiet && git diff --cached --quiet; then
  echo "cursor_edit_verified=false"
else
  echo "cursor_edit_verified=true"
fi
echo "cursor_agent_output_bytes=$(wc -c <"$out" | tr -d ' ')"
