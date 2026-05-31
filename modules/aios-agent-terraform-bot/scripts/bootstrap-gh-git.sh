#!/usr/bin/env bash
# GitHub + git auth bootstrap for terraform-bot Ubuntu sandboxes (orchestration §0a).
set -euo pipefail

GIT_TOKEN="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
export GIT_TOKEN="$GIT_TOKEN" GH_TOKEN="$GIT_TOKEN" GITHUB_TOKEN="$GIT_TOKEN"
export GIT_TERMINAL_PROMPT=0

if [ -z "$GIT_TOKEN" ]; then
  echo "gh_env_present=false"
  exit 1
fi

echo "gh_env_present=true"
gh auth setup-git
git config --global user.name "stackgen-terraform-bot"
git config --global user.email "terraform-bot@stackgen.local"
