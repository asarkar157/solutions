#!/usr/bin/env bash
# G1 greenfield — new L3 construct + test only (no edits to sample-stack.ts).
#
# Better than legacy T1 ("Add S3 bucket construct"): explicit paths, unique token,
# verifiable Template assertions, and a bounded scope the agent can finish in one PR.
#
# Usage:
#   ./scripts/trigger-greenfield-g1.sh
#   ./scripts/trigger-greenfield-g1.sh --repo owner/cdk-typescript-demo
#   ./scripts/trigger-greenfield-g1.sh --no-create-issue --issue 42
set -euo pipefail

SCENARIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${CDK_BOT_TEST_REPO:-sks/cdk-typescript-demo}"
CREATE_ISSUE=1
ISSUE_NUM=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --no-create-issue) CREATE_ISSUE=0; shift ;;
    --issue) ISSUE_NUM="$2"; CREATE_ISSUE=0; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

TOKEN="$(date +%Y%m%d-%H%M%S)"
LIB_FILE="lib/gf-archive-bucket-${TOKEN}.ts"
TEST_FILE="test/gf-archive-bucket-${TOKEN}.test.ts"
CLASS_NAME="GfArchiveBucket${TOKEN//-/}"

TITLE="G1 greenfield: VersionedArchiveBucket ${TOKEN}"
BODY="$(cat <<EOF
Greenfield L3 construct — **add new files only**. Do not modify \`lib/sample-stack.ts\`, \`test/sample-stack.test.ts\`, or \`bin/app.ts\`.

Run token: \`${TOKEN}\`

## Deliverables (both files MUST exist on disk before commit-pr)
1. \`${LIB_FILE}\` — export \`${CLASS_NAME}\` extending \`Construct\`
   - Creates one S3 bucket with versioning enabled
   - Server-side encryption: SSE-S3 (\`BucketEncryption.S3_MANAGED\`)
   - Lifecycle rule: transition objects to \`GLACIER\` after 90 days
   - \`removalPolicy: DESTROY\`, \`autoDeleteObjects: true\`
2. \`${TEST_FILE}\` — Jest + \`aws-cdk-lib/assertions\` Template test
   - Assert exactly one \`AWS::S3::Bucket\`
   - Assert \`VersioningConfiguration.Status\` is \`Enabled\`
   - Assert lifecycle transition to \`GLACIER\` at 90 days

## Implement checklist (implement-cdk stage)
- Spawn contract: **two** \`execute_series\` + **one** \`create_files\` for the edit script (no bash heredoc inside the script — use \`python3 -c\` or simple \`sed\`).
- Edit script must create both deliverable files; verify with \`test -f ${LIB_FILE} && test -f ${TEST_FILE}\` before commit-pr.
- Required stdout marker: \`implement_edit_verified=true\`

## PR
- Branch: \`cdk-bot/gf-${TOKEN}\`
- Draft PR when implement + validate pass

## Out of scope
- No changes to existing stacks or app entrypoint
- No new npm dependencies
EOF
)"

args=(
  --from-tofu-output
  --repo "$REPO"
  --title "$TITLE"
  --body "$BODY"
)
if [ "$CREATE_ISSUE" -eq 1 ]; then
  args+=(--create-github-issue)
fi
if [ -n "$ISSUE_NUM" ]; then
  args+=(--issue "$ISSUE_NUM")
fi

echo "g1_token=${TOKEN}"
echo "g1_lib=${LIB_FILE}"
echo "g1_test=${TEST_FILE}"
exec "${SCENARIO_DIR}/scripts/trigger-webhook.sh" "${args[@]}"
