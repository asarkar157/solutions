#!/usr/bin/env bash
# Smoke-check that aios-agent-db-state-splitter templatefile() inputs render
# (catches tftpl syntax errors before apply). OpenTofu/Terraform built-ins
# only — no StackGen credentials required.
#
# The Terraform fixture (main.tf) lives alongside this script under
# fixtures/db-state-split-templates/ so we avoid in-script heredocs (some
# bash 5.x builds hang on multi-heredoc scripts) and so the expected vars
# stay in sync with the module's locals.template_vars contract. Variable
# defaults are baked into main.tf so we don't need a .tfvars file (which
# would be excluded by repo-wide *.tfvars gitignore).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="${ROOT}/modules/aios-agent-db-state-splitter"
FIXTURE="${ROOT}/scripts/fixtures/db-state-split-templates"
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

mkdir -p "${TMP}/templates" "${TMP}/personas"
cp "${MOD}/templates/"*.tftpl "${TMP}/templates/"
cp "${MOD}/personas/"*.tftpl "${TMP}/personas/"
cp "${FIXTURE}/main.tf" "${TMP}/main.tf"

(cd "${TMP}" && "${TF_BIN}" init -backend=false -input=false >/dev/null && "${TF_BIN}" validate >/dev/null)
echo "verify-db-state-split-templates: OK (${TF_BIN})"
