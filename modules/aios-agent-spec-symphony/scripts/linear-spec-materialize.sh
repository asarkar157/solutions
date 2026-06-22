#!/usr/bin/env bash
# Write specs/<id>/ from Linear comment content (WF2 materialize-spec).
set -euo pipefail

REPO_DIR="${1:?repo_dir}"
FEATURE_ID="${2:?feature_id}"
SPEC_MARKDOWN="${SPEC_MARKDOWN:-}"
SUBGOALS="${ENGINEERING_SUBGOALS:-}"

if [ -z "$SPEC_MARKDOWN" ] && [ -n "${SPEC_MARKDOWN_FILE:-}" ] && [ -f "$SPEC_MARKDOWN_FILE" ]; then
  SPEC_MARKDOWN="$(cat "$SPEC_MARKDOWN_FILE")"
fi

if [ -z "$SPEC_MARKDOWN" ]; then
  echo "materialize_blocker=missing_spec_markdown"
  exit 1
fi

cd "$REPO_DIR"
base="specs/${FEATURE_ID}"
mkdir -p "$base"

cat >"$base/spec.md" <<EOF
${SPEC_MARKDOWN}
EOF

cat >"$base/plan.md" <<EOF
# Plan: ${FEATURE_ID}

Implement engineering subgoals from the blessed Linear spec comment.
Engine: ${LINEAR_IMPLEMENT_ENGINE:-cursor_cli}
EOF

{
  echo "# Tasks: ${FEATURE_ID}"
  echo ""
  if [ -n "$SUBGOALS" ]; then
    printf '%s\n' "$SUBGOALS"
  else
    echo "- [ ] Implement per spec.md acceptance criteria"
  fi
} >"$base/tasks.md"

echo "spec_artifact_path=specs/${FEATURE_ID}"
echo "spec_tasks_path=specs/${FEATURE_ID}/tasks.md"
echo "spec_linkage_recorded=true"
echo "stage_summary:materialize-spec=done"
