#!/usr/bin/env bash
# Smoke-check that aios-agent-db-state-splitter templatefile() inputs render (catches tftpl syntax errors before apply).
# OpenTofu/Terraform built-ins only — no StackGen credentials required.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD="${ROOT}/modules/aios-agent-db-state-splitter"
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

cat >"${TMP}/main.tf" <<'EOF'
terraform {
  required_version = ">= 1.5"
}
variable "max_iterations" { type = number }
variable "remote_runner_block" { type = string }
output "rendered" {
  value = trimspace(templatefile("${path.module}/fixture.tftpl", {
    max_iterations      = var.max_iterations
    remote_runner_block = var.remote_runner_block
  }))
}
EOF
cp "${MOD}/templates/db-state-split-orchestration.md.tftpl" "${TMP}/fixture.tftpl"

cat >"${TMP}/terraform.tfvars" <<'EOF'
max_iterations      = 5
remote_runner_block = "ci-smoke-runner-block"
EOF

(cd "${TMP}" && "${TF_BIN}" init -backend=false -input=false >/dev/null && "${TF_BIN}" validate >/dev/null)
echo "verify-db-state-split-templates: OK (${TF_BIN})"
