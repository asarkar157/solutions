#!/usr/bin/env bash
# Unit-style test for boundary-scan.sh against a synthetic Go + TypeScript + Java tree.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="${ROOT}/scripts/boundary-scan.sh"
WORK="$(mktemp -d)"
REPO="${WORK}/sample-repo"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$REPO/pkg/core" "$REPO/src/test/java/com/example"
cat >"$REPO/go.mod" <<'EOF'
module example.com/monorepo

go 1.22
EOF
cat >"$REPO/pkg/core/core.go" <<'EOF'
package core

func Hello() string { return "hello" }
EOF
cat >"$REPO/pkg/core/core_test.go" <<'EOF'
package core

import "testing"

func TestHello(t *testing.T) {
	tests := []struct {
		name string
		want string
	}{
		{"default", "hello"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Hello(); got != tt.want {
				t.Errorf("Hello() = %q, want %q", got, tt.want)
			}
		})
	}
}
EOF
cat >"$REPO/package.json" <<'EOF'
{
  "name": "web",
  "private": true,
  "scripts": {
    "test": "vitest run"
  }
}
EOF
cat >"$REPO/vitest.config.ts" <<'EOF'
import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { environment: 'node' } });
EOF
mkdir -p "$REPO/src/lib"
cat >"$REPO/src/lib/greet.test.ts" <<'EOF'
import { describe, it, expect } from 'vitest';
describe('greet', () => {
  it('returns hello', () => {
    expect('hello').toBe('hello');
  });
});
EOF
cat >"$REPO/pom.xml" <<'EOF'
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>monorepo</artifactId>
  <version>1.0</version>
  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>3.2.5</version>
      </plugin>
    </plugins>
  </build>
</project>
EOF
cat >"$REPO/src/test/java/com/example/CoreTest.java" <<'EOF'
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CoreTest {
  @Test void passes() { assertTrue(true); }
}
EOF

chmod +x "$SCAN"
MONOREPO_SPLIT_ALLOW_DIRECT=1 bash "$SCAN" scan "$WORK" "$REPO" >/tmp/boundary-scan-test.out

if ! grep -q 'boundary_scan_ok=true' /tmp/boundary-scan-test.out; then
  echo "FAIL: boundary scan did not emit boundary_scan_ok=true" >&2
  cat /tmp/boundary-scan-test.out >&2
  exit 1
fi

if [ ! -f "$WORK/boundary_scan.json" ]; then
  echo "FAIL: boundary_scan.json not written" >&2
  exit 1
fi

for lang in go typescript java; do
  if ! jq -e ".languages | index(\"${lang}\")" "$WORK/boundary_scan.json" >/dev/null; then
    echo "FAIL: expected ${lang} in languages array" >&2
    jq . "$WORK/boundary_scan.json" >&2
    exit 1
  fi
done

if ! jq -e '.test_inventory.go.test_files_count >= 1' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected go test_inventory with test files" >&2
  jq '.test_inventory' "$WORK/boundary_scan.json" >&2
  exit 1
fi

if ! jq -e '.test_inventory.java.junit_detected == true' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected junit_detected in java test_inventory" >&2
  jq '.test_inventory.java' "$WORK/boundary_scan.json" >&2
  exit 1
fi

if ! jq -e '.test_inventory.typescript.test_files_count >= 1' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected typescript test files in test_inventory" >&2
  jq '.test_inventory.typescript' "$WORK/boundary_scan.json" >&2
  exit 1
fi

if ! jq -e '.test_frameworks | index("go_test")' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected go_test in test_frameworks" >&2
  jq '.test_frameworks' "$WORK/boundary_scan.json" >&2
  exit 1
fi

if ! jq -e '.test_frameworks | index("junit5")' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected junit5 in test_frameworks" >&2
  jq '.test_frameworks' "$WORK/boundary_scan.json" >&2
  exit 1
fi

if ! jq -e 'has("packages_without_tests") and (.packages_without_tests | type) == "array"' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected packages_without_tests array" >&2
  exit 1
fi

if ! jq -e '.test_confidence_score >= 0 and .test_confidence_score <= 1' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: test_confidence_score must be between 0 and 1" >&2
  jq '.test_confidence_score' "$WORK/boundary_scan.json" >&2
  exit 1
fi

if ! jq -e '.test_confidence_score > 0' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected positive test_confidence_score for repo with tests" >&2
  exit 1
fi

if ! grep -q 'test_confidence_score=' /tmp/boundary-scan-test.out; then
  echo "FAIL: scan stdout should emit test_confidence_score" >&2
  exit 1
fi

if ! jq -e 'has("cloud_entitlements") and (.cloud_entitlements.scan_status | type) == "string"' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected cloud_entitlements object with scan_status in boundary_scan.json" >&2
  jq '.cloud_entitlements' "$WORK/boundary_scan.json" >&2
  exit 1
fi

if ! jq -e 'has("cce_plan") and (.cce_plan.candidate_file_count | type) == "number"' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected cce_plan.candidate_file_count in boundary_scan.json" >&2
  jq '.cce_plan' "$WORK/boundary_scan.json" >&2
  exit 1
fi

if ! jq -e 'has("critical_path_dirs") and (.critical_path_dirs | type) == "array"' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected critical_path_dirs array in boundary_scan.json" >&2
  exit 1
fi

if ! jq -e 'has("cce_reports")' "$WORK/boundary_scan.json" >/dev/null; then
  echo "FAIL: expected cce_reports in boundary_scan.json" >&2
  exit 1
fi

if ! jq -e '.cce_summary != null' "$WORK/notes.json" 2>/dev/null; then
  if [ -f "$WORK/notes.json" ] && ! jq -e 'has("cce_summary")' "$WORK/notes.json" >/dev/null; then
    echo "FAIL: expected cce_summary in notes.json" >&2
    exit 1
  fi
fi

echo "OK: boundary-scan.sh synthetic repo test passed (cloud_entitlements=$(jq -r '.cloud_entitlements.scan_status' "$WORK/boundary_scan.json"))"
