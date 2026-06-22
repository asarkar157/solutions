#!/usr/bin/env bash
# ensure-shell-tool.sh — install missing CLIs on the CDK runner (sudo apt preferred).
# Usage: ensure-shell-tool.sh <tool>   (e.g. rg)
# Emits: ensure_shell_tool=<tool> on success; ensure_shell_tool_error= on failure.
set -euo pipefail

apt_install_pkg() {
  local pkg="${1:?pkg}"
  if command -v sudo >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg"
    return 0
  fi
  if [ "$(id -u)" -eq 0 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg"
    return 0
  fi
  return 1
}

ensure_rg() {
  export PATH="${HOME}/.local/bin:${PATH}"
  if command -v rg >/dev/null 2>&1; then
    echo "ensure_shell_tool=rg"
    return 0
  fi

  if apt_install_pkg ripgrep && command -v rg >/dev/null 2>&1; then
    echo "ensure_shell_tool=rg"
    return 0
  fi

  local arch="" ver="${CDKBOT_RIPGREP_VERSION:-14.1.1}"
  case "$(uname -m)" in
    x86_64 | amd64) arch="x86_64" ;;
    aarch64 | arm64) arch="aarch64" ;;
    *)
      echo "ensure_shell_tool_error=unsupported_arch tool=rg"
      return 1
      ;;
  esac

  mkdir -p "${HOME}/.local/bin"
  local tmp url
  tmp="$(mktemp -d)"
  url="https://github.com/BurntSushi/ripgrep/releases/download/${ver}/ripgrep-${ver}-${arch}-unknown-linux-gnu.tar.gz"
  curl -fsSL "$url" | tar -xzf - -C "$tmp" --strip-components=1
  cp "$tmp/rg" "${HOME}/.local/bin/rg"
  chmod +x "${HOME}/.local/bin/rg"
  rm -rf "$tmp"

  if ! command -v rg >/dev/null 2>&1; then
    echo "ensure_shell_tool_error=rg_install_failed"
    return 1
  fi
  echo "ensure_shell_tool=rg"
}

ensure_shell_tool() {
  local tool="${1:?tool}"
  case "$tool" in
    rg | ripgrep) ensure_rg ;;
    *)
      echo "ensure_shell_tool_error=unknown_tool tool=${tool}"
      return 1
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  ensure_shell_tool "$@"
fi
