#!/usr/bin/env bash
# docker_build_smoke.sh — verify CDK runner Dockerfile builds (same args as docker.tf local-exec).
# Does not push; production images are still built on the apply host via `tofu apply` unless you
# adopt a registry-first workflow (build in CI, set build_runner_image = false, pull by tag).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACK_VERSION="$("${ROOT}/scripts/read-script-pack-version.sh")"

BASE_IMAGE="${AIDEN_RUNNER_IMAGE:-ghcr.io/appcd-dev/stackgen-guild-aiden-runner:main}"
IMAGE="${CDK_BOT_RUNNER_IMAGE:-cdk-bot-runner:${PACK_VERSION}-ci-smoke}"

echo "Building ${IMAGE} (SCRIPT_PACK_VERSION=${PACK_VERSION}, base=${BASE_IMAGE})"
docker build \
  -t "${IMAGE}" \
  --build-arg "AIDEN_RUNNER_IMAGE=${BASE_IMAGE}" \
  --build-arg "SCRIPT_PACK_VERSION=${PACK_VERSION}" \
  -f "${ROOT}/docker/Dockerfile" \
  "${ROOT}"

docker run --rm --entrypoint bash "${IMAGE}" -lc 'test -x "${CDKBOT_PACK_DIR}/validate-cdk.sh" && test -x "${CDKBOT_PACK_DIR}/clone-pack.sh"'
echo "OK: docker_build_smoke (${IMAGE})"
