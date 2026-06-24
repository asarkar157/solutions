#!/usr/bin/env bash
# Cursor CLI implement — tasks.md anchored edits in repo_clone_path.
set -euo pipefail

REPO_DIR="${1:?repo_dir}"
TASKS_PATH="${2:-tasks.md}"
TICKET="${3:-}"

PROMPT="Read .specify/memory/constitution.md when present. Implement only what ${TASKS_PATH} requires.
Ticket context: ${TICKET:-n/a}
When finished, ensure specs/, openspec/changes/, or aidlc-docs/ and code change together.
Emit implement_edit_verified=true when edits are complete."

PACK_DIR="${SPECSYM_PACK_DIR:-$(dirname "$0")}"
if ! out="$("${PACK_DIR}/cursor-agent.sh" "$REPO_DIR" "$PROMPT")"; then
  echo "implement_blocker=cursor_failed"
  exit 1
fi
printf '%s\n' "$out"
if grep -q 'cursor_edit_verified=false' <<<"$out"; then
  echo "implement_edit_verified=false"
  echo "implement_blocker=no_edits"
  exit 1
fi
echo "implement_edit_verified=true"
echo "implement_summary=cursor_cli"
echo "stage_summary:implement=done"
