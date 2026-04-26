#!/usr/bin/env bash
# Run init -backend=false and validate in every directory under modules/ and examples/
# that contains at least one .tf file.
# Prefers OpenTofu (`tofu`); falls back to HashiCorp Terraform (`terraform`) — same flags.
# Same discovery logic as the OpenTofu validate job in .github/workflows/ci.yml.
#
# When a CLI config file lists dev_overrides for the StackGen provider, validate can use
# a stale local binary that does not match these modules (e.g. missing sg_guild_integration.id
# or old provider "sg" argument names). This script then sets TF_CLI_CONFIG_FILE to
# scripts/terraform-validate-cli.tfrc so init/validate use published providers (like CI).
#
# Detection: if TF_CLI_CONFIG_FILE is set, that file is checked; otherwise ~/.terraformrc.
# Override: AIOS_VALIDATE_RESPECT_HOMERC=1 keeps your normal CLI config.
# Force minimal config: AIOS_VALIDATE_USE_MINIMAL_CLI_CONFIG=1
#
# With the minimal config, registry auth must come from TF_TOKEN_releases_stackgen_com
# (credentials blocks in ~/.terraformrc are not loaded).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

_cli_config_has_dev_overrides() {
  local f="$1"
  [[ -n "${f}" && -f "${f}" ]] && grep -qE '[[:space:]]*dev_overrides[[:space:]]*\{' "${f}" 2>/dev/null
}

if [[ -z "${AIOS_VALIDATE_RESPECT_HOMERC:-}" ]]; then
  if [[ -n "${AIOS_VALIDATE_USE_MINIMAL_CLI_CONFIG:-}" ]]; then
    export TF_CLI_CONFIG_FILE="${ROOT}/scripts/terraform-validate-cli.tfrc"
  else
    _cfg="${TF_CLI_CONFIG_FILE:-}"
    if [[ -z "${_cfg}" ]]; then
      _cfg="${HOME}/.terraformrc"
    fi
    if _cli_config_has_dev_overrides "${_cfg}"; then
      export TF_CLI_CONFIG_FILE="${ROOT}/scripts/terraform-validate-cli.tfrc"
    fi
  fi
fi

if command -v tofu >/dev/null 2>&1; then
  TF_BIN=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF_BIN=terraform
else
  echo "error: neither 'tofu' (OpenTofu) nor 'terraform' found in PATH" >&2
  exit 1
fi
echo "Using ${TF_BIN} (install OpenTofu for the default; HashiCorp Terraform is interchangeable)"

if ! find modules examples -type f -name '*.tf' -print -quit 2>/dev/null | grep -q .; then
  echo "No Terraform directories found under modules/ or examples/."
  exit 0
fi

failed=0
while IFS= read -r dir; do
  [[ -z "${dir}" ]] && continue
  echo "==> ${TF_BIN} validate: ${dir}"
  # -upgrade: lock files may pin an older provider than required_providers allows; refresh for validate-only runs.
  if (cd "${dir}" && "${TF_BIN}" init -backend=false -input=false -upgrade && "${TF_BIN}" validate); then
    :
  else
    failed=1
  fi
done < <(find modules examples -type f -name '*.tf' 2>/dev/null | sed 's|/[^/]*$||' | sort -u)

exit "${failed}"
