#!/usr/bin/env bash
# Tests for runtime-deps-provision.sh (Java version detection + baseline test skip path).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVISION="${ROOT}/scripts/runtime-deps-provision.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

chmod +x "$PROVISION"

java_repo="${WORK}/java-repo"
mkdir -p "$java_repo"
printf '17\n' >"$java_repo/.java-version"
if [ "$(bash "$PROVISION" detect-java-version "$java_repo")" != "17" ]; then
  echo "FAIL: expected Java 17 from .java-version" >&2
  exit 1
fi

gradle_repo="${WORK}/gradle-repo"
mkdir -p "$gradle_repo"
cat >"$gradle_repo/build.gradle.kts" <<'EOF'
plugins { java }
java { toolchain { languageVersion.set(JavaLanguageVersion.of(21)) } }
EOF
if [ "$(bash "$PROVISION" detect-java-version "$gradle_repo")" != "21" ]; then
  echo "FAIL: expected Java 21 from Gradle toolchain" >&2
  exit 1
fi

scan="${WORK}/boundary_scan.json"
repo="${WORK}/sample"
mkdir -p "$repo"
cat >"$scan" <<'EOF'
{
  "languages": ["go"],
  "test_inventory": {
    "go": { "recommended_command": "go test ./..." }
  }
}
EOF

out="$(MONOREPO_SPLIT_RUN_BASELINE_TESTS=0 bash "$PROVISION" baseline-tests "$WORK" "$repo" "$scan")"
if ! grep -q 'baseline_test_status=skipped' <<<"$out"; then
  echo "FAIL: expected baseline skip when MONOREPO_SPLIT_RUN_BASELINE_TESTS=0" >&2
  echo "$out" >&2
  exit 1
fi

if ! grep -q 'runtime-deps-provision.sh' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must invoke runtime-deps-provision.sh" >&2
  exit 1
fi

echo "OK: runtime-deps-provision tests passed"
