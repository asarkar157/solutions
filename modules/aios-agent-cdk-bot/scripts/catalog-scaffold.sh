#!/usr/bin/env bash
# catalog-scaffold.sh — thin entry for CDK catalog repo greenfield scaffold.
set -euo pipefail
runner="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stage-runner.sh"
export CDKBOT_ALLOW_DIRECT=1
exec "$runner" catalog-scaffold "$@"
