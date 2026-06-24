#!/usr/bin/env bash
# local-run-g1.sh — deterministic script-pack run for G1 greenfield (no Guild LLM).
# Proves clone → implement (new lib+test files) → validate path for the G1 scenario.
set -euo pipefail

SCENARIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${SCENARIO_DIR}/../../.." && pwd)"
MOD="${REPO_ROOT}/modules/aios-agent-cdk-bot"
PACK="${MOD}/scripts"

TOKEN="$(date +%Y%m%d-%H%M%S)"
LIB_FILE="lib/gf-archive-bucket-${TOKEN}.ts"
TEST_FILE="test/gf-archive-bucket-${TOKEN}.test.ts"
CLASS_NAME="GfArchiveBucket${TOKEN//-/}"

CLONE_URL="${CLONE_URL:-https://github.com/sks/cdk-typescript-demo.git}"
BRANCH="${BRANCH:-main}"
ISSUE_NUM="${ISSUE_NUM:-1}"
REPO_FULL="${REPO_FULL:-sks/cdk-typescript-demo}"

PACK_VERSION="$(bash "${PACK}/read-script-pack-version.sh" 2>/dev/null || echo "20260624.1")"
WORK_ROOT="${WORK_ROOT:-/tmp/cdk-bot-local-g1-${TOKEN}}"
export CDKBOT_ALLOW_DIRECT=1
export CDKBOT_PACK_DIR="$PACK"
export SCRIPT_PACK_VERSION="$PACK_VERSION"

log() { printf '==> %s\n' "$*"; }

write_greenfield_edit_script() {
  local edit_sh="${1:?}"
  local repo_dir="${2:?}"
  cat >"$edit_sh" <<EDITSCRIPT
#!/usr/bin/env bash
set -euo pipefail
cd $(printf %q "$repo_dir")
python3 -c "
from pathlib import Path
lib = Path('${LIB_FILE}')
test = Path('${TEST_FILE}')
lib.parent.mkdir(parents=True, exist_ok=True)
test.parent.mkdir(parents=True, exist_ok=True)
lib.write_text('''import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export class ${CLASS_NAME} extends Construct {
  public readonly bucket: s3.Bucket;

  constructor(scope: Construct, id: string) {
    super(scope, id);
    this.bucket = new s3.Bucket(this, 'ArchiveBucket', {
      versioned: true,
      encryption: s3.BucketEncryption.S3_MANAGED,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      lifecycleRules: [{ transitions: [{ storageClass: s3.StorageClass.GLACIER, transitionAfter: cdk.Duration.days(90) }] }],
    });
  }
}
''')
test.write_text('''import { App, Stack } from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { ${CLASS_NAME} } from '../${LIB_FILE%.ts}';

describe('${CLASS_NAME}', () => {
  it('creates versioned archive bucket with glacier transition', () => {
    const app = new App();
    const stack = new Stack(app, 'TestStack');
    new ${CLASS_NAME}(stack, 'Archive');
    const template = Template.fromStack(stack);
    template.resourceCountIs('AWS::S3::Bucket', 1);
    template.hasResourceProperties('AWS::S3::Bucket', {
      VersioningConfiguration: { Status: 'Enabled' },
      LifecycleConfiguration: {
        Rules: [{ Transitions: [{ StorageClass: 'GLACIER', TransitionInDays: 90 }] }],
      },
    });
  });
});
''')
"
test -f '${LIB_FILE}' && test -f '${TEST_FILE}'
EDITSCRIPT
  chmod +x "$edit_sh"
}

mkdir -p "$WORK_ROOT"
log "G1 local run token=${TOKEN} work_root=${WORK_ROOT}"

log "1/4 clone"
bash "${PACK}/clone-pack.sh" clone "$WORK_ROOT" "$CLONE_URL" "$BRANCH" "$ISSUE_NUM" "" "" \
  | tee "$WORK_ROOT/clone.out"
REPO="$(grep -E '^repo_clone_path=' "$WORK_ROOT/clone.out" | tail -1 | cut -d= -f2-)"
[ -d "$REPO" ] || { echo "FAIL: no repo_clone_path" >&2; exit 1; }

log "2/4 implement-app"
bash "${PACK}/stage-runner.sh" implement-app-preflight "$REPO" | tee "$WORK_ROOT/preflight.out"
bash "${PACK}/stage-runner.sh" prepare-implement-edits "$WORK_ROOT" "$REPO" | tee "$WORK_ROOT/prepare.out"
EDIT_SH="${WORK_ROOT}/.work/implement-edits.sh"
write_greenfield_edit_script "$EDIT_SH" "$REPO"
bash "${PACK}/stage-runner.sh" implement-app-run "$REPO" "$EDIT_SH" "gf_archive_${TOKEN}" \
  | tee "$WORK_ROOT/implement.out"
grep -q 'implement_edit_verified=true' "$WORK_ROOT/implement.out" || { echo "FAIL: implement" >&2; exit 1; }
[ -f "${REPO}/${LIB_FILE}" ] && [ -f "${REPO}/${TEST_FILE}" ] || { echo "FAIL: missing deliverable files" >&2; exit 1; }

log "3/4 validate"
bash "${PACK}/stage-runner.sh" validate "$WORK_ROOT" "$REPO" 2>&1 | tee "$WORK_ROOT/validate.out"
grep -E '^(validation_summary|module_quality_summary)=' "$WORK_ROOT/validate.out"
grep -q '^module_quality_summary=PASS' "$WORK_ROOT/validate.out" || {
  echo "FAIL: validate did not PASS (see ${WORK_ROOT}/validate.out)" >&2
  exit 1
}

log "PASS G1 local — ${LIB_FILE} + ${TEST_FILE}"
echo "work_root=${WORK_ROOT}"
