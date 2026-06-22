#!/usr/bin/env bash
# Initialize Spec Kit or OpenSpec in cloned repo when missing; seed SDD Kit starter.
set -euo pipefail

REPO_DIR="${1:?repo_dir}"
FRAMEWORK="${SDD_FRAMEWORK:-auto}"
CHANGE_TYPE="${CHANGE_TYPE:-brownfield}"
PACK_DIR="${SPECSYM_PACK_DIR:-}"

detect_framework() {
  if [ "$FRAMEWORK" = "spec-kit" ] || [ "$FRAMEWORK" = "openspec" ]; then
    printf '%s' "$FRAMEWORK"
    return 0
  fi
  if [ -d "$REPO_DIR/openspec" ]; then
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
