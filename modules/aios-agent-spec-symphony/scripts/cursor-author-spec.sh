#!/usr/bin/env bash
# Cursor CLI author-spec — thin ticket → spec/plan/tasks.
set -euo pipefail

REPO_DIR="${1:?repo_dir}"
FEATURE_ID="${2:-}"
TITLE="${3:-Spec-driven feature}"
BODY="${4:-}"

PROMPT="Read .specify/memory/constitution.md when present.
When sdd_framework=ai-dlc, read AGENTS.md or .cursor/rules/ai-dlc-workflow.mdc and .aidlc-rule-details/ for AWS AI-DLC workflow guidance.
Author Spec Kit, OpenSpec, or AI-DLC artifacts for ticket ${FEATURE_ID:-unknown}.
Title: ${TITLE}
Description: ${BODY}
Create or update specs/${FEATURE_ID}/ (spec.md, plan.md, tasks.md) OR openspec/changes/${FEATURE_ID}/ (proposal.md, tasks.md) OR aidlc-docs/${FEATURE_ID}/ (inception.md, construction.md, operations.md) matching repo layout.
For AI-DLC: include ## Open Questions in inception.md when context is thin.
Do not implement code yet — specification artifacts only."

PACK_DIR="${SPECSYM_PACK_DIR:-$(dirname "$0")}"
"${PACK_DIR}/cursor-agent.sh" "$REPO_DIR" "$PROMPT"
echo "author_spec_status=ok"
echo "spec_linkage_recorded=true"
echo "stage_summary:author-spec=done"
