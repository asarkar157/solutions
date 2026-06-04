#!/usr/bin/env bash
# Smoke-check terraform-bot workflow script pack template rendering.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="${ROOT}/modules/aios-agent-terraform-bot"
FIXTURE="${ROOT}/scripts/fixtures/terraform-bot-workflow-scripts"
TMP="$(mktemp -d)"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

if command -v tofu >/dev/null 2>&1; then
  TF_BIN=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF_BIN=terraform
else
  echo "error: need tofu or terraform in PATH" >&2
  exit 1
fi

mkdir -p "${TMP}/scripts" "${TMP}/templates"
cp "${MOD}/scripts/"*.sh "${TMP}/scripts/"
cp "${MOD}/templates/workflow-script-pack.md.tftpl" "${TMP}/templates/"
cp "${FIXTURE}/main.tf" "${TMP}/main.tf"

(cd "${TMP}" && "${TF_BIN}" init -backend=false -input=false >/dev/null && "${TF_BIN}" validate >/dev/null)

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "error: shellcheck required (brew install shellcheck)" >&2
  exit 1
fi

for script in "${MOD}/scripts/"*.sh; do
  shellcheck -S warning -x "$script"
done

echo "verify-terraform-bot-workflow-scripts: OK (${TF_BIN})"
