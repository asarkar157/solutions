#!/usr/bin/env bash
# GitHub + git auth bootstrap for cdk-bot remote runner sandboxes (orchestration §0a).
# Repeat invocation is safe: setup-git failures are non-fatal when clone already configured git (trace 52cabb6c).
set -euo pipefail

GIT_TOKEN="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
export GIT_TOKEN
export GH_TOKEN="$GIT_TOKEN"
export GITHUB_TOKEN="$GIT_TOKEN"
export GIT_TERMINAL_PROMPT=0

if [ -z "$GIT_TOKEN" ]; then
  echo "gh_env_present=false"
  exit 1
fi

echo "gh_env_present=true"
if ! gh auth setup-git 2>/dev/null; then
  echo "gh_setup_git_warning=setup_git_failed" >&2
fi
git config --global user.name "stackgen-cdk-bot" 2>/dev/null || true
git config --global user.email "cdk-bot@stackgen.local" 2>/dev/null || true
