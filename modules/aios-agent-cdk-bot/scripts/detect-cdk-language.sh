#!/usr/bin/env bash
# detect-cdk-language.sh — infer CDK language and app root from a cloned repo path.
# Emits: cdk_language=, cdk_app_root=, test_runner=
set -euo pipefail

target="${1:-.}"
if [ ! -d "$target" ]; then
  echo "cdk_language=unknown"
  echo "cdk_app_root="
  echo "test_runner=unknown"
  exit 1
fi

cdk_app_root=""
cdk_language="unknown"
test_runner="unknown"

# Walk up from target to find cdk.json
search="$target"
while [ "$search" != "/" ] && [ -n "$search" ]; do
  if [ -f "$search/cdk.json" ]; then
    cdk_app_root="$search"
    break
  fi
  search="$(dirname "$search")"
done

if [ -z "$cdk_app_root" ] && [ -f "$target/cdk.json" ]; then
  cdk_app_root="$target"
fi

if [ -z "$cdk_app_root" ]; then
  # Monorepo: first cdk.json under target
  found="$(find "$target" -maxdepth 4 -name cdk.json -print -quit 2>/dev/null || true)"
  if [ -n "$found" ]; then
    cdk_app_root="$(dirname "$found")"
  fi
fi

if [ -z "$cdk_app_root" ]; then
  echo "cdk_language=unknown"
  echo "cdk_app_root="
  echo "test_runner=unknown"
  exit 0
fi

app_cmd=""
if command -v jq >/dev/null 2>&1 && [ -f "$cdk_app_root/cdk.json" ]; then
  app_cmd="$(jq -r '.app // empty' "$cdk_app_root/cdk.json" 2>/dev/null || true)"
fi

if [ -f "$cdk_app_root/package.json" ]; then
  cdk_language="typescript"
  if [ -f "$cdk_app_root/vitest.config.ts" ] || [ -f "$cdk_app_root/vitest.config.mts" ]; then
    test_runner="vitest"
  else
    test_runner="jest"
  fi
fi

if [ -f "$cdk_app_root/pyproject.toml" ] || [ -f "$cdk_app_root/requirements.txt" ] || [ -f "$cdk_app_root/requirements-dev.txt" ]; then
  if printf '%s' "$app_cmd" | grep -qi python; then
    cdk_language="python"
    test_runner="pytest"
  fi
  if [ -f "$cdk_app_root/app.py" ] && [ "$cdk_language" = "unknown" ]; then
    cdk_language="python"
    test_runner="pytest"
  fi
fi

if [ "$cdk_language" = "unknown" ] && [ -f "$cdk_app_root/tsconfig.json" ]; then
  cdk_language="typescript"
  test_runner="jest"
fi

echo "cdk_language=${cdk_language}"
echo "cdk_app_root=${cdk_app_root}"
echo "test_runner=${test_runner}"
