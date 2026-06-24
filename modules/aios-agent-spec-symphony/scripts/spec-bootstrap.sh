#!/usr/bin/env bash
# Initialize Spec Kit or OpenSpec in cloned repo when missing; seed SDD Kit starter.
set -euo pipefail

REPO_DIR="${1:?repo_dir}"
FRAMEWORK="${SDD_FRAMEWORK:-auto}"
CHANGE_TYPE="${CHANGE_TYPE:-brownfield}"
PACK_DIR="${SPECSYM_PACK_DIR:-}"

resolve_aidlc_vendor_rules() {
  local pack="${1:?pack_dir}"
  if [ -d "${pack}/vendor/aidlc-rules/aws-aidlc-rule-details" ]; then
    printf '%s' "${pack}/vendor/aidlc-rules"
    return 0
  fi
  if [ -d "${pack}/.generated/aidlc-rules/aws-aidlc-rule-details" ]; then
    printf '%s' "${pack}/.generated/aidlc-rules"
    return 0
  fi
  printf '%s' "${pack}/vendor/aidlc-rules"
}

detect_framework() {
  if [ "$FRAMEWORK" = "spec-kit" ] || [ "$FRAMEWORK" = "openspec" ] || [ "$FRAMEWORK" = "ai-dlc" ]; then
    printf '%s' "$FRAMEWORK"
    return 0
  fi
  if [ -d "$REPO_DIR/aidlc-docs" ] || [ -d "$REPO_DIR/.aidlc-rule-details" ]; then
    echo ai-dlc
  elif [ -d "$REPO_DIR/openspec" ]; then
    echo openspec
  elif [ -d "$REPO_DIR/.specify" ]; then
    echo spec-kit
  elif [ "$CHANGE_TYPE" = "greenfield" ]; then
    echo spec-kit
  else
    echo openspec
  fi
}

fw="$(detect_framework)"
echo "sdd_framework_used=$fw"

cd "$REPO_DIR"
starter="${PACK_DIR}/templates/sdd-kit-starter"

case "$fw" in
  ai-dlc)
    mkdir -p aidlc-docs
    vendor_rules="$(resolve_aidlc_vendor_rules "${PACK_DIR}")"
    if [ -d "$vendor_rules/aws-aidlc-rule-details" ]; then
      mkdir -p .aidlc-rule-details
      cp -rn "$vendor_rules/aws-aidlc-rule-details/." .aidlc-rule-details/ 2>/dev/null || true
    fi
    core_workflow="${vendor_rules}/aws-aidlc-rules/core-workflow.md"
    if [ -f "$core_workflow" ]; then
      if [ ! -f AGENTS.md ]; then
        cp "$core_workflow" AGENTS.md
      fi
      if [ ! -f .cursor/rules/ai-dlc-workflow.mdc ]; then
        mkdir -p .cursor/rules
        {
          printf '%s\n' '---'
          printf '%s\n' 'description: "AI-DLC (AI-Driven Development Life Cycle) adaptive workflow for software development"'
          printf '%s\n' 'alwaysApply: true'
          printf '%s\n' '---'
          printf '\n'
          cat "$core_workflow"
        } >.cursor/rules/ai-dlc-workflow.mdc
      fi
    fi
    if [ -d "$starter/ai-dlc" ]; then
      cp -rn "$starter/ai-dlc/." aidlc-docs/ 2>/dev/null || true
    fi
    ;;
  openspec)
    if [ ! -d openspec ]; then
      openspec init . --yes 2>/dev/null || openspec init . 2>/dev/null || mkdir -p openspec/specs openspec/changes
    fi
    if [ -d "$starter/openspec" ]; then
      cp -rn "$starter/openspec/." openspec/ 2>/dev/null || true
    fi
    ;;
  spec-kit)
    if [ ! -d .specify ]; then
      specify init . --force --ignore-agent-tools 2>/dev/null \
        || specify init . --force 2>/dev/null || mkdir -p .specify
    fi
    if [ -f "$starter/constitution.md" ] && [ ! -f .specify/memory/constitution.md ]; then
      mkdir -p .specify/memory
      cp "$starter/constitution.md" .specify/memory/constitution.md
    fi
    ;;
esac

if [ -f "$starter/SPEC_SYMPHONY.md" ] && [ ! -f SPEC_SYMPHONY.md ]; then
  cp "$starter/SPEC_SYMPHONY.md" SPEC_SYMPHONY.md
fi
if [ -f "$starter/change-types/${CHANGE_TYPE}.md" ] && [ ! -f "docs/change-type-${CHANGE_TYPE}.md" ]; then
  mkdir -p docs
  cp "$starter/change-types/${CHANGE_TYPE}.md" "docs/change-type-${CHANGE_TYPE}.md"
fi

echo "spec_bootstrap=ok"
echo "stage_summary:repo-sdd-bootstrap=done"
