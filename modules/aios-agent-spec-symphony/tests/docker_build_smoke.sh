#!/usr/bin/env bash
# docker_build_smoke.sh — verify spec-symphony runner Dockerfile builds (same args as docker.tf).
# Does not push; production images are published by .github/workflows/spec-symphony-docker.yml on main.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_VERSION="$("${ROOT}/scripts/read-script-pack-version.sh")"
AIDLC_VERSION="$("${ROOT}/scripts/read-aidlc-rules-version.sh")"

BASE_IMAGE="${AIDEN_RUNNER_IMAGE:-ghcr.io/appcd-dev/stackgen-guild-aiden-runner:main}"
IMAGE="${SPECSYM_RUNNER_IMAGE:-spec-symphony-runner:${PACK_VERSION}-ci-smoke}"
INSTALL_CURSOR="${INSTALL_CURSOR_CLI:-0}"

if [ "$INSTALL_CURSOR" = "1" ]; then
  ALLOWED_CLIS="bash,sh,sudo,apt-get,apt,git,gh,jq,npm,specify,openspec,agent,cursor"
else
  ALLOWED_CLIS="bash,sh,sudo,apt-get,apt,git,gh,jq,npm,specify,openspec"
fi

echo "Fetching AI-DLC rules ${AIDLC_VERSION} for Docker build context"
"${ROOT}/scripts/fetch-aidlc-rules.sh" "${AIDLC_VERSION}" "${ROOT}/.generated/aidlc-rules"

echo "Building ${IMAGE} (SCRIPT_PACK_VERSION=${PACK_VERSION}, base=${BASE_IMAGE}, INSTALL_CURSOR_CLI=${INSTALL_CURSOR})"
docker build \
  -t "${IMAGE}" \
  --build-arg "AIDEN_RUNNER_IMAGE=${BASE_IMAGE}" \
  --build-arg "SCRIPT_PACK_VERSION=${PACK_VERSION}" \
  --build-arg "INSTALL_CURSOR_CLI=${INSTALL_CURSOR}" \
  --build-arg "ALLOWED_CLIS=${ALLOWED_CLIS}" \
  -f "${ROOT}/docker/Dockerfile" \
  "${ROOT}"

docker run --rm --entrypoint sh "${IMAGE}" -c \
  'test -x "${SPECSYM_PACK_DIR}/stage-runner.sh" && test -f "${SPECSYM_PACK_DIR}/vendor/aidlc-rules/VERSION"'
echo "OK: docker_build_smoke (${IMAGE})"
