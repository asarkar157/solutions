#!/usr/bin/env bash
# Author spec/plan/tasks from ticket context when missing (thin-ticket bootstrap).
set -euo pipefail

REPO_DIR="${1:?repo_dir}"
FRAMEWORK="${SDD_FRAMEWORK:-auto}"
CHANGE_TYPE="${CHANGE_TYPE:-brownfield}"
FEATURE_ID="${FEATURE_ID:-}"
ISSUE_TITLE="${ISSUE_TITLE:-Spec-driven feature}"
ISSUE_BODY="${ISSUE_BODY:-}"

feature_id_from_env() {
  local fid="${FEATURE_ID:-}"
  if [ -n "$fid" ]; then
    printf '%s' "$fid"
    return 0
  fi
  fid="$(printf '%s' "${ISSUE_OR_PR:-}" | grep -oE '([A-Z]+-[0-9]+)' | head -1 || true)"
  if [ -n "$fid" ]; then
    printf '%s' "$fid"
    return 0
  fi
  if [ -n "${ISSUE_OR_PR:-}" ]; then
    printf 'issue-%s' "${ISSUE_OR_PR}"
    return 0
  fi
  return 1
}

detect_framework() {
  if [ "$FRAMEWORK" = "spec-kit" ] || [ "$FRAMEWORK" = "openspec" ] || [ "$FRAMEWORK" = "ai-dlc" ]; then
    printf '%s' "$FRAMEWORK"
    return 0
  fi
  if [ -d "$REPO_DIR/aidlc-docs" ] || [ -d "$REPO_DIR/.aidlc-rule-details" ]; then
    echo ai-dlc
  elif [ -d "$REPO_DIR/openspec/changes" ] || [ -d "$REPO_DIR/openspec" ]; then
    echo openspec
  elif [ -d "$REPO_DIR/.specify" ] || [ -d "$REPO_DIR/specs" ]; then
    echo spec-kit
  elif [ "$CHANGE_TYPE" = "greenfield" ]; then
    echo spec-kit
  else
    echo openspec
  fi
}

write_spec_kit_artifacts() {
  local fid="$1"
  local base="specs/${fid}"
  mkdir -p "$base"
  if [ ! -f "$base/spec.md" ]; then
    cat >"$base/spec.md" <<EOF
# ${ISSUE_TITLE}

## Ticket
${ISSUE_BODY:-_(no description in webhook payload — fill acceptance criteria)_}

## Acceptance criteria
- [ ] Implement the requested change
- [ ] Spec and code change together (SDD linkage)

## Change type
${CHANGE_TYPE}
EOF
  fi
  if [ ! -f "$base/plan.md" ]; then
    cat >"$base/plan.md" <<EOF
# Plan: ${fid}

1. Read constitution and existing codebase
2. Implement tasks in \`tasks.md\`
3. Run validate (tests, lint, ci-spec-linkage)
EOF
  fi
  if [ ! -f "$base/tasks.md" ]; then
    cat >"$base/tasks.md" <<EOF
# Tasks: ${fid}

- [ ] Implement feature per spec.md
- [ ] Update tests as needed
- [ ] Ensure specs/${fid}/ changes with code changes
EOF
  fi
  echo "spec_artifact_path=specs/${fid}"
  echo "spec_tasks_path=specs/${fid}/tasks.md"
}

write_openspec_artifacts() {
  local fid="$1"
  local base="openspec/changes/${fid}"
  mkdir -p "$base"
  if [ ! -f "$base/proposal.md" ]; then
    cat >"$base/proposal.md" <<EOF
# Change: ${fid}

## Why
${ISSUE_TITLE}

## What
${ISSUE_BODY:-_(no description — add scope)_}

## Change type
${CHANGE_TYPE}
EOF
  fi
  if [ ! -f "$base/tasks.md" ]; then
    cat >"$base/tasks.md" <<EOF
# Tasks: ${fid}

- [ ] Implement change per proposal.md
- [ ] Update openspec/changes/${fid}/ with spec linkage
EOF
  fi
  echo "spec_artifact_path=openspec/changes/${fid}"
  echo "spec_tasks_path=openspec/changes/${fid}/tasks.md"
}

write_ai_dlc_artifacts() {
  local fid="$1"
  local base="aidlc-docs/${fid}"
  mkdir -p "$base"
  if [ ! -f "$base/inception.md" ]; then
    cat >"$base/inception.md" <<EOF
# Inception: ${fid}

## Unit of Work
${ISSUE_TITLE}

## Business intent
${ISSUE_BODY:-_(no description in webhook payload — fill acceptance criteria)_}

## Acceptance criteria
- [ ] Implement the requested change
- [ ] Spec and code change together (SDD linkage)

## Change type
${CHANGE_TYPE}

## Open Questions
- [ ] _(Add structured multiple-choice questions here when ticket context is thin — do not block in chat)_
EOF
  fi
  if [ ! -f "$base/construction.md" ]; then
    cat >"$base/construction.md" <<EOF
# Construction: ${fid}

## Component design
1. Read constitution and existing codebase
2. Implement tasks below
3. Run validate (tests, lint, ci-spec-linkage)

## Tasks
- [ ] Implement feature per inception.md
- [ ] Update tests as needed
- [ ] Ensure aidlc-docs/${fid}/ changes with code changes
EOF
  fi
  if [ ! -f "$base/operations.md" ]; then
    cat >"$base/operations.md" <<EOF
# Operations: ${fid}

## Deployment notes
_(Future: deployment automation, monitoring, production readiness)_

## Rollout / validation
- [ ] CI passes
- [ ] PR reviewed and approved (human-in-the-loop)
EOF
  fi
  echo "spec_artifact_path=aidlc-docs/${fid}"
  echo "spec_tasks_path=aidlc-docs/${fid}/construction.md"
}

main() {
  cd "$REPO_DIR"
  local fid fw
  if ! fid="$(feature_id_from_env)"; then
    echo "author_spec_blocker=missing_ticket_context"
    echo "stage_summary:author-spec=blocked"
    exit 1
  fi
  fw="$(detect_framework)"
  case "$fw" in
    spec-kit) write_spec_kit_artifacts "$fid" ;;
    openspec) write_openspec_artifacts "$fid" ;;
    ai-dlc) write_ai_dlc_artifacts "$fid" ;;
    *)
      echo "author_spec_blocker=unknown_framework"
      exit 1
      ;;
  esac
  if [ -f ".specify/memory/constitution.md" ]; then
    echo "constitution_present=true"
  elif [ -f "constitution.md" ]; then
    echo "constitution_present=true"
  else
    echo "constitution_present=false"
  fi
  echo "author_spec_status=ok"
  echo "spec_linkage_recorded=true"
  echo "spec_artifacts_committed=pending"
  echo "stage_summary:author-spec=done"
}

main
