#!/usr/bin/env bash
set -euo pipefail
tool="${1:?tool}"
case "$tool" in
  rg)
    if command -v rg >/dev/null 2>&1; then
      echo "ensure_shell_tool=rg"
      exit 0
    fi
    if command -v sudo >/dev/null 2>&1; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ripgrep
    fi
    command -v rg >/dev/null && echo "ensure_shell_tool=rg" || echo "ensure_shell_tool_error=rg"
    ;;
  *) echo "ensure_shell_tool_error=unknown tool=$tool" ;;
esac
