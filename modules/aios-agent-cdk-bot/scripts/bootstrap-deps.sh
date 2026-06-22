#!/usr/bin/env bash
# bootstrap-deps.sh — install CDK app dependencies (npm or python venv).
# Usage: bootstrap-deps.sh <app_root> [cdk_language]
# Emits: deps_exit=0|1
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ensure-cdk-toolchain.sh
source "${script_dir}/ensure-cdk-toolchain.sh"

app_root="${1:?app_root}"
lang="${2:-}"

if [ -z "$lang" ] && [ -x "$(dirname "$0")/detect-cdk-language.sh" ]; then
  lang="$( "$(dirname "$0")/detect-cdk-language.sh" "$app_root" | awk -F= '/^cdk_language=/{print $2}')"
fi

if [ ! -d "$app_root" ]; then
  echo "deps_exit=1"
  echo "deps_error=app_root_missing"
  exit 1
fi

cd "$app_root"
deps_rc=0

if [ "$lang" = "typescript" ] || [ -f package.json ]; then
  if ! ensure_cdk_toolchain; then
    echo "deps_error=node_install_failed"
    echo "deps_exit=1"
    exit 1
  fi
  if [ -f package-lock.json ]; then
    npm ci --no-audit --no-fund >/dev/null 2>&1 || deps_rc=$?
  elif [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then
    pnpm install --frozen-lockfile >/dev/null 2>&1 || deps_rc=$?
  elif [ -f yarn.lock ] && command -v yarn >/dev/null 2>&1; then
    yarn install --frozen-lockfile >/dev/null 2>&1 || deps_rc=$?
  elif [ -f package.json ]; then
    npm install --no-audit --no-fund >/dev/null 2>&1 || deps_rc=$?
  else
    echo "deps_error=missing_lockfile"
    deps_rc=1
  fi
fi

if [ "$lang" = "python" ] || [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if [ ! -d .venv ]; then
    python3 -m venv .venv || deps_rc=$?
  fi
  # shellcheck disable=SC1091
  . .venv/bin/activate
  if [ -f requirements.txt ]; then
    pip install -q -r requirements.txt || deps_rc=$?
  fi
  if [ -f requirements-dev.txt ]; then
    pip install -q -r requirements-dev.txt || deps_rc=$?
  fi
  if [ -f pyproject.toml ] && command -v pip >/dev/null 2>&1; then
    pip install -q -e ".[dev]" 2>/dev/null || pip install -q -e . 2>/dev/null || true
  fi
fi

echo "deps_exit=${deps_rc}"
exit "$deps_rc"
