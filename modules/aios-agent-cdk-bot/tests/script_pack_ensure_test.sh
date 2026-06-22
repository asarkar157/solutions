#!/usr/bin/env bash
# script_pack_ensure_test.sh — pack ensure materializes scripts from tarball env (mothership sync path).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_VERSION="20260616.12"
PACK_DIR="$(mktemp -d)/.cdk-bot/pack/${PACK_VERSION}"
mkdir -p "$PACK_DIR/.work"

tarball_b64="$(tar -czf - -C "${ROOT}/scripts" . | base64 | tr -d '\n')"
runner_sha="$(sha256sum "${ROOT}/scripts/stage-runner.sh" | awk '{print $1}')"
clone_sha="$(sha256sum "${ROOT}/scripts/clone-pack.sh" | awk '{print $1}')"

ensure_body="$(sed \
  -e "s|\${cdkbot_pack_dir}|${PACK_DIR}|g" \
  -e "s|\${script_pack_version}|${PACK_VERSION}|g" \
  -e "s|\${script_pack_runner_sha256}|${runner_sha}|g" \
  -e "s|\${script_pack_clone_sha256}|${clone_sha}|g" \
  -e 's|\${pack_missing_hint}|test_hint|g' \
  -e 's|\$\${|\${|g' \
  "${ROOT}/templates/cdkbot-pack-ensure-shell.sh.tftpl" | tr '\n' ' ')"

export CDKBOT_SCRIPT_PACK_TARBALL_B64="$tarball_b64"
export CDKBOT_SCRIPT_PACK_VERSION="$PACK_VERSION"
sh -c "$ensure_body"

test -x "${PACK_DIR}/stage-runner.sh"
test -x "${PACK_DIR}/validate-cdk.sh"
test -f "${PACK_DIR}/.script_pack_version"
grep -q "${PACK_VERSION}" "${PACK_DIR}/.script_pack_version"

echo "OK: script_pack_ensure_test"
