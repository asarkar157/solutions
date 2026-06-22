#!/usr/bin/env bash
# ensure-cdk-toolchain.sh — user-local Node.js + npm for CDK TypeScript (no sudo).
# Sourced or executed before npm/cdk commands in the Ubuntu sandbox.
set -euo pipefail

ensure_cdk_toolchain() {
  export PATH="${HOME}/.local/node/bin:${HOME}/.local/bin:${PATH}"

  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    return 0
  fi

  local arch narch version node_dir tarball
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) narch="x64" ;;
    aarch64 | arm64) narch="arm64" ;;
    *)
      echo "toolchain_error=unsupported_arch" >&2
      return 1
      ;;
  esac

  version="${CDKBOT_NODE_VERSION:-22.11.0}"
  node_dir="${HOME}/.local/node"
  mkdir -p "$node_dir"
  tarball="/tmp/node-v${version}-linux-${narch}.tar.xz"

  if [ ! -x "${node_dir}/bin/node" ]; then
    curl -fsSL "https://nodejs.org/dist/v${version}/node-v${version}-linux-${narch}.tar.xz" -o "$tarball"
    tar -xJf "$tarball" -C "$node_dir" --strip-components=1
    rm -f "$tarball"
  fi

  export PATH="${node_dir}/bin:${PATH}"
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  ensure_cdk_toolchain
  node --version
  npm --version
fi
