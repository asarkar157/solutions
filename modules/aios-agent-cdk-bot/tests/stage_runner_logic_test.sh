#!/usr/bin/env bash
# stage_runner_logic_test.sh — smoke tests for CDK script pack helpers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_TS="${ROOT}/../../examples/fixtures/cdk-repos/generic-typescript"
FIXTURE_PY="${ROOT}/../../examples/fixtures/cdk-repos/generic-python"

echo "detect-cdk-language (typescript)"
out="$("${ROOT}/scripts/detect-cdk-language.sh" "$FIXTURE_TS")"
echo "$out" | grep -q 'cdk_language=typescript'

echo "detect-cdk-language (python)"
out="$("${ROOT}/scripts/detect-cdk-language.sh" "$FIXTURE_PY")"
echo "$out" | grep -q 'cdk_language=python'

echo "resolve-paths expands literal \$HOME work root"
wr_parent="$(mktemp -d)"
export HOME="$wr_parent"
work_root='$HOME/.wf-resolve-test'
repo_dir="$wr_parent/.wf-resolve-test/repo"
mkdir -p "$repo_dir"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
printf '{"app":"npx ts-node"}' >"$repo_dir/cdk.json"
git -C "$repo_dir" add cdk.json
git -C "$repo_dir" commit -q -m "init"
resolve_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" resolve-paths '$HOME/.wf-resolve-test' '$HOME/.wf-resolve-test/repo' main '')"
printf '%s' "$resolve_out" | grep -q 'repo_kind=cdk_app'
test -f "$wr_parent/.wf-resolve-test/notes.json"

echo "resolve_module_path_arg ignores stale repo outside work_root"
wr_parent="$(mktemp -d)"
current_wr="$wr_parent/.wf-current"
stale_wr="$wr_parent/.wf-stale"
mkdir -p "$stale_wr/repo"
git -C "$stale_wr/repo" init -q
git -C "$stale_wr/repo" config user.email "test@test.com"
git -C "$stale_wr/repo" config user.name "test"
echo "stale" >"$stale_wr/repo/README.md"
git -C "$stale_wr/repo" add README.md
git -C "$stale_wr/repo" commit -q -m "init"
mkdir -p "$current_wr"
echo '{}' >"$current_wr/notes.json"
jq --arg p "$stale_wr/repo" '. + {repo_clone_path: $p, module_paths: $p}' "$current_wr/notes.json" >"$current_wr/notes.json.tmp" && mv "$current_wr/notes.json.tmp" "$current_wr/notes.json"
resolved="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" prepare-implement-edits "$current_wr" '<module_paths from read_notes>' | grep '^module_path=' | sed 's/^module_path=//')"
if [ "$resolved" != "$current_wr/repo" ]; then
  echo "FAIL: expected module_path=$current_wr/repo when stale note exists but repo missing, got '$resolved'" >&2
  exit 1
fi

echo "check-work-root-clone detects stale repo_clone_path outside work_root"
if ready_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" check-work-root-clone "$current_wr" 2>&1)"; then
  echo "FAIL: check-work-root-clone should fail when notes point outside work_root: $ready_out" >&2
  exit 1
fi
printf '%s' "$ready_out" | grep -q 'clone_blocker=stale_repo_clone_path'

echo "check-work-root-clone detects missing repo when notes are empty"
empty_wr="$(mktemp -d)/.wf-empty"
mkdir -p "$empty_wr"
echo '{}' >"$empty_wr/notes.json"
if missing_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" check-work-root-clone "$empty_wr" 2>&1)"; then
  echo "FAIL: check-work-root-clone should fail when repo missing: $missing_out" >&2
  exit 1
fi
printf '%s' "$missing_out" | grep -q 'clone_blocker=repo_missing'

echo "check-work-root-clone accepts clone under work_root"
mkdir -p "$current_wr/repo"
git -C "$current_wr/repo" init -q
git -C "$current_wr/repo" config user.email "test@test.com"
git -C "$current_wr/repo" config user.name "test"
echo "ok" >"$current_wr/repo/README.md"
git -C "$current_wr/repo" add README.md
git -C "$current_wr/repo" commit -q -m "init"
ready_ok="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" check-work-root-clone "$current_wr")"
printf '%s' "$ready_ok" | grep -q 'repo_clone_ready=true'
printf '%s' "$ready_ok" | grep -q "repo_clone_path=$current_wr/repo"

echo "prepare-implement-edits resolves spawn placeholder to WORK_ROOT/repo"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-placeholder"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir"
git -C "$repo_dir" init -q >/dev/null 2>&1
prepare_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" prepare-implement-edits "$work_root" '<module_paths from read_notes>')"
printf '%s' "$prepare_out" | grep -Fq "module_path=$repo_dir"

echo "implement-app-preflight lists lib sources"
preflight_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-preflight "$FIXTURE_TS")"
printf '%s' "$preflight_out" | grep -q 'implement_preflight_ok=true'
if printf '%s' "$preflight_out" | grep -qF -- '--- file:'; then
  echo "FAIL: preflight file listings must be on stderr, not stdout" >&2
  exit 1
fi

echo "implement-app-run recovers from failing edit script via builtin KMS migration"
git -C "$FIXTURE_TS" checkout -- lib/sample-stack.ts test/sample-stack.test.ts 2>/dev/null || true
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-kms"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir"
cp -a "$FIXTURE_TS/." "$repo_dir/"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "init"
kms_body='Enable KMS encryption on the S3 bucket in lib/sample-stack.ts using KMS_MANAGED and aws:kms.'
jq -n \
  --arg body "$kms_body" \
  --arg repo "$repo_dir" \
  '{issue_details: {number: 1, title: "Fix encryption on SampleStack", body: $body}, issue_or_pr_number: "1", repository_full_name: "sks/cdk-typescript-demo", repo_clone_path: $repo}' \
  >"$work_root/notes.json"
fail_edit="$(mktemp)"
cat >"$fail_edit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmp -s /nonexistent /also-missing
EOF
chmod +x "$fail_edit"
run_recover="$(CDKBOT_ALLOW_DIRECT=1 CDKBOT_SKIP_ISSUE_FETCH=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-run "$repo_dir" "$fail_edit" 'kms via builtin fallback' 2>&1)"
printf '%s' "$run_recover" | grep -q 'implement_edit_recovered=builtin_kms_after_script_failure'
printf '%s' "$run_recover" | grep -q 'implement_edit_verified=true'
printf '%s' "$run_recover" | grep -q 'implement_markers_file='
printf '%s' "$run_recover" | grep -q 'implement_summary=kms via builtin fallback'
grep -q 'KMS_MANAGED' "$repo_dir/lib/sample-stack.ts"
grep -q "aws:kms" "$repo_dir/test/sample-stack.test.ts"
rm -f "$fail_edit"

echo "implement-app-postcheck recovers block public access brownfield via builtin fallback"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-bpa"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir"
cp -a "$FIXTURE_TS/." "$repo_dir/"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "init"
issue_body='Brownfield — edit only lib/sample-stack.ts. Add blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL to SampleStack bucket.'
jq -n \
  --arg body "$issue_body" \
  --arg repo "$repo_dir" \
  '{issue_details: {number: 20, title: "B2 block public access", body: $body}, issue_or_pr_number: "20", repository_full_name: "sks/cdk-typescript-demo", repo_clone_path: $repo}' \
  >"$work_root/notes.json"
bpa_out="$(CDKBOT_ALLOW_DIRECT=1 CDKBOT_SKIP_ISSUE_FETCH=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-postcheck "$work_root" "$repo_dir" 2>&1)"
printf '%s' "$bpa_out" | grep -q 'implement_edit_verified=true'
grep -q 'BlockPublicAccess.BLOCK_ALL' "$repo_dir/lib/sample-stack.ts"

echo "implement-app-postcheck recovers G2 notification queue greenfield scaffold"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-g2"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir"
cp -a "$FIXTURE_TS/." "$repo_dir/"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "init"
g2_body='Greenfield L3 — add new files only. Do not modify lib/sample-stack.ts.

## Deliverables
1. lib/gf-notification-queue-demo.ts — export GfNotificationQueue construct
2. test/gf-notification-queue-demo.test.ts — Jest test for SQS queue + DLQ'
jq -n \
  --arg body "$g2_body" \
  --arg repo "$repo_dir" \
  '{issue_details: {number: 19, title: "G2 notification queue", body: $body}, issue_or_pr_number: "19", repository_full_name: "sks/cdk-typescript-demo", repo_clone_path: $repo}' \
  >"$work_root/notes.json"
g2_out="$(CDKBOT_ALLOW_DIRECT=1 CDKBOT_SKIP_ISSUE_FETCH=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-postcheck "$work_root" "$repo_dir" 2>&1)"
printf '%s' "$g2_out" | grep -q 'implement_edit_verified=true'
test -f "$repo_dir/lib/gf-notification-queue-demo.ts"
test -f "$repo_dir/test/gf-notification-queue-demo.test.ts"
grep -q 'AWS::SQS::Queue' "$repo_dir/test/gf-notification-queue-demo.test.ts"

echo "implement-app-run builtin KMS recovery with relative MODULE_PATH argv"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-kms-rel"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir"
cp -a "$FIXTURE_TS/." "$repo_dir/"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "init"
kms_body='Enable KMS encryption on the S3 bucket in lib/sample-stack.ts using KMS_MANAGED.'
jq -n \
  --arg body "$kms_body" \
  --arg repo "$repo_dir" \
  '{issue_details: {number: 2, title: "Fix encryption on SampleStack", body: $body}, issue_or_pr_number: "2", repository_full_name: "sks/cdk-typescript-demo", repo_clone_path: $repo}' \
  >"$work_root/notes.json"
fail_edit="$(mktemp)"
cat >"$fail_edit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmp -s /nonexistent /also-missing
EOF
chmod +x "$fail_edit"
run_rel="$(cd "$work_root" && CDKBOT_ALLOW_DIRECT=1 CDKBOT_SKIP_ISSUE_FETCH=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-run "repo" "$fail_edit" 'kms relative path' 2>&1)"
printf '%s' "$run_rel" | grep -q 'implement_edit_recovered=builtin_kms_after_script_failure'
printf '%s' "$run_rel" | grep -q 'implement_edit_verified=true'
rm -f "$fail_edit"
rm -rf "${FIXTURE_TS}/examples" 2>/dev/null || true

echo "read-implement-markers prints durable marker file"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-markers"
mkdir -p "$work_root/.work"
printf '%s\n' 'implement_edit_verified=true' 'implement_summary=from file' 'cdk_language=typescript' >"$work_root/.work/implement-markers.env"
markers_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" read-implement-markers "$work_root")"
printf '%s' "$markers_out" | grep -q 'implement_edit_verified=true'
printf '%s' "$markers_out" | grep -q 'implement_summary=from file'

echo "implement-app-postcheck rejects clean tree"
wr_parent="$(mktemp -d)"
postcheck_repo="$wr_parent/repo"
mkdir -p "$postcheck_repo"
cp -a "$FIXTURE_TS/." "$postcheck_repo/"
git -C "$postcheck_repo" init -q
git -C "$postcheck_repo" config user.email "test@test.com"
git -C "$postcheck_repo" config user.name "test"
git -C "$postcheck_repo" add -A
git -C "$postcheck_repo" commit -q -m "init"
if postcheck_fail="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-postcheck "$postcheck_repo" 2>&1)"; then
  echo "FAIL: postcheck should fail when lib/ unchanged: $postcheck_fail" >&2
  exit 1
fi
printf '%s' "$postcheck_fail" | grep -q 'implement_blocker=no_file_edits'

echo "implement-app-postcheck accepts edits"
echo "// postcheck test" >>"${postcheck_repo}/lib/sample-stack.ts"
postcheck_ok="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-postcheck "$postcheck_repo")"
printf '%s' "$postcheck_ok" | grep -q 'implement_edit_verified=true'

echo "normalize-work-root expands \$HOME token"
wr_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" normalize-work-root '$HOME/.wf-normalize-test')"
Expect_wr="${HOME}/.wf-normalize-test"
if [ "$wr_out" != "$Expect_wr" ]; then
  echo "FAIL: normalize-work-root got '$wr_out' want '$Expect_wr'" >&2
  exit 1
fi

echo "prepare-implement-edits infers work_root from MODULE_PATH when prefixed on subprocess"
prep_mod_out="$(CDKBOT_ALLOW_DIRECT=1 MODULE_PATH="$FIXTURE_TS" bash "${ROOT}/scripts/stage-runner.sh" prepare-implement-edits | grep '^edit_script=')"
printf '%s' "$prep_mod_out" | grep -q 'edit_script=.*implement-edits.sh'

echo "prepare-implement-edits expands \$HOME work root (argv)"
wr_parent="$(mktemp -d)"
export HOME="$wr_parent"
prep_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" prepare-implement-edits '$HOME/.wf-implement-prep')"
printf '%s' "$prep_out" | grep -q "work_root=$wr_parent/.wf-implement-prep"
printf '%s' "$prep_out" | grep -q "edit_script=$wr_parent/.wf-implement-prep/.work/implement-edits.sh"
printf '%s' "$prep_out" | grep -q 'implement_edit_scaffold=true'
test -x "$wr_parent/.wf-implement-prep/.work/implement-edits.sh"

echo "prepare-implement-edits fails without work_root in subprocess"
if missing_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" prepare-implement-edits 2>&1)"; then
  echo "FAIL: prepare-implement-edits should fail without work_root arg: $missing_out" >&2
  exit 1
fi
printf '%s' "$missing_out" | grep -q 'implement_blocker=work_root_missing'

echo "validate-and-pr accepts positional argv without exported env"
wr="$(mktemp -d)"
mod="$wr/repo"
mkdir -p "$mod"
touch "$mod/cdk.json"
val_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" validate-and-pr "$wr" "$mod" 'org/repo' '42' 'main' 'true' 2>&1)" || true
printf '%s' "$val_out" | grep -qE '^(error=missing_MODULE_PATH|validation_error=|fmt_exit=)'

echo "implement-app-run rejects empty edit script path"
if empty_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-run "$FIXTURE_TS" '' 'summary' 2>&1)"; then
  echo "FAIL: implement-app-run should fail on empty edit script: $empty_out" >&2
  exit 1
fi
printf '%s' "$empty_out" | grep -q 'implement_blocker=edit_script_path_empty'

echo "implement-app-run rejects mangled edit script with literal backslash-n"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-mangled-reject"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir" "$work_root/.work"
cp -a "$FIXTURE_TS/." "$repo_dir/"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "init"
jq -n \
  --arg body 'Greenfield L3 — add new files only. Do not modify lib/sample-stack.ts.' \
  '{issue_details: {number: 99, title: "G-only", body: $body}, issue_or_pr_number: "99"}' \
  >"$work_root/notes.json"
bad_edit="$work_root/.work/implement-edits.sh"
printf '%s\n' '#!/bin/bash' 'echo literal\\nbroken' 'true' >"$bad_edit"
chmod +x "$bad_edit"
if bad_run="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-run "$repo_dir" "$bad_edit" 'x' 2>&1)"; then
  echo "FAIL: implement-app-run should reject mangled edit script: $bad_run" >&2
  exit 1
fi
printf '%s' "$bad_run" | grep -q 'implement_blocker=edit_script_mangled_escapes'
rm -f "$bad_edit"

echo "implement-app-run recovers B2 block-public-access from mangled edit script"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-mangled-b2"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir"
cp -a "$FIXTURE_TS/." "$repo_dir/"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "init"
jq -n \
  --arg body "Brownfield — edit lib/sample-stack.ts only. Add blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL to SampleStack S3 bucket." \
  '{issue_or_pr_number: "27", repository_full_name: "sks/cdk-typescript-demo", issue_body: $body}' \
  >"$work_root/notes.json"
bad_b2_edit="$(mktemp)"
printf '%s\n' '#!/bin/bash' 'echo literal\\nbroken' 'true' >"$bad_b2_edit"
chmod +x "$bad_b2_edit"
mangled_b2_out="$(CDKBOT_ALLOW_DIRECT=1 CDKBOT_SKIP_ISSUE_FETCH=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-run "$repo_dir" "$bad_b2_edit" 'block public access' 2>&1)" || true
if ! printf '%s' "$mangled_b2_out" | grep -q 'implement_edit_recovered=builtin_block_public_access_mangled_escapes'; then
  echo "FAIL: mangled B2 edit should recover via builtin block public access: $mangled_b2_out" >&2
  exit 1
fi
grep -q 'blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL' "$repo_dir/lib/sample-stack.ts"
rm -f "$bad_b2_edit"

echo "implement-app-run rejects edit script with heredoc"
heredoc_edit="$(mktemp)"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'cat <<EOF' 'broken' >"$heredoc_edit"
chmod +x "$heredoc_edit"
if heredoc_run="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-run "$FIXTURE_TS" "$heredoc_edit" 'x' 2>&1)"; then
  echo "FAIL: implement-app-run should reject heredoc edit script: $heredoc_run" >&2
  exit 1
fi
printf '%s' "$heredoc_run" | grep -q 'implement_blocker=edit_script_heredoc_forbidden'
rm -f "$heredoc_edit"

echo "implement-app-run rejects edit script with sed range address (trace f7a79c2a)"
range_edit="$(mktemp)"
cat >"$range_edit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd .
sed -i '/new s3.Bucket(/,/}/ { /encryption: /d; /}/i \    encryption: s3.BucketEncryption.KMS_MANAGED,' lib/sample-stack.ts
EOF
chmod +x "$range_edit"
if range_run="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-run "$FIXTURE_TS" "$range_edit" 'x' 2>&1)"; then
  echo "FAIL: implement-app-run should reject sed-range edit script: $range_run" >&2
  exit 1
fi
printf '%s' "$range_run" | grep -q 'implement_blocker=edit_script_sed_range_forbidden'
rm -f "$range_edit"

echo "implement-app-run rejects edit script with unclosed bash quote"
quote_edit="$(mktemp)"
printf '%s\n' '#!/usr/bin/env bash' "sed -i 'unclosed" >"$quote_edit"
chmod +x "$quote_edit"
if quote_run="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-run "$FIXTURE_TS" "$quote_edit" 'x' 2>&1)"; then
  echo "FAIL: implement-app-run should reject unclosed-quote edit script: $quote_run" >&2
  exit 1
fi
printf '%s' "$quote_run" | grep -q 'implement_blocker=edit_script_syntax_error'
rm -f "$quote_edit"

echo "implement-app-run executes edit script and emits markers"
wr_parent="$(mktemp -d)"
run_repo="$wr_parent/repo"
mkdir -p "$run_repo"
cp -a "$FIXTURE_TS/." "$run_repo/"
git -C "$run_repo" init -q
git -C "$run_repo" config user.email "test@test.com"
git -C "$run_repo" config user.name "test"
git -C "$run_repo" add -A
git -C "$run_repo" commit -q -m "init"
edit_sh="$(mktemp)"
cat >"$edit_sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "// implement-app-run test" >>lib/sample-stack.ts
EOF
chmod +x "$edit_sh"
run_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" implement-app-run "$run_repo" "$edit_sh" 'test edit applied')"
printf '%s' "$run_out" | grep -q 'implement_preflight_ok=true'
printf '%s' "$run_out" | grep -q 'implement_edit_verified=true'
printf '%s' "$run_out" | grep -q 'implement_summary=test edit applied'
printf '%s' "$run_out" | grep -q 'cdk_language=typescript'
rm -f "$edit_sh"

echo "clone-pack rejects unexpanded \$REPO_CLONE_URL argv"
wr="$(mktemp -d)"
if unexpanded_out="$(CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/clone-pack.sh" clone "$wr" '$REPO_CLONE_URL' main 1 2>&1)"; then
  echo "FAIL: clone-pack should reject literal \$REPO_CLONE_URL arg: $unexpanded_out" >&2
  exit 1
fi
printf '%s' "$unexpanded_out" | grep -q 'clone_blocker=unexpanded_shell_var'

echo "bootstrap-gh-git.sh tolerates repeat invocation (trace 52cabb6c)"
bootstrap_out="$(GIT_TOKEN=fake bash "${ROOT}/scripts/bootstrap-gh-git.sh" 2>&1)"
printf '%s' "$bootstrap_out" | grep -q 'gh_env_present=true'
bootstrap_out2="$(GIT_TOKEN=fake bash "${ROOT}/scripts/bootstrap-gh-git.sh" 2>&1)"
printf '%s' "$bootstrap_out2" | grep -q 'gh_env_present=true'

echo "commit-pr builds PR body for CDK app without exit 123 (trace dfe1ba4c)"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-cdk-commit-pr"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir"
cp -a "$FIXTURE_TS/." "$repo_dir/"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "init"
echo '// commit-pr cdk test' >>"$repo_dir/lib/sample-stack.ts"
jq -n \
  --arg repo "$repo_dir" \
  '{repo_kind: "cdk_app", module_paths: $repo, cdk_app_root: $repo, cdk_language: "typescript", implement_summary: "test cdk change"}' \
  >"$work_root/notes.json"
cdk_commit_out="$(GIT_TOKEN=fake CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" commit-pr "$work_root" 'org/cdk-typescript-demo' '1' '' 'main' 2>&1)" || cdk_commit_status=$?
cdk_commit_status="${cdk_commit_status:-0}"
if [ "$cdk_commit_status" -eq 123 ]; then
  echo "FAIL: commit-pr exited 123 on CDK repo (GNU xargs/grep): $cdk_commit_out" >&2
  exit 1
fi
if ! test -s "$work_root/.work/pr-body.md"; then
  echo "FAIL: commit-pr should write pr-body.md for CDK repo: $cdk_commit_out" >&2
  exit 1
fi
grep -q 'CDK validation' "$work_root/.work/pr-body.md"
git -C "$repo_dir" log -1 --format=%s | grep -q 'feat(cdk):'

echo "commit-pr greenfield PR title/body without repo_kind in notes (trace PR#12)"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-gf-pr"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir"
cp -a "$FIXTURE_TS/." "$repo_dir/"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
git -C "$repo_dir" add -A
git -C "$repo_dir" commit -q -m "init"
mkdir -p "$repo_dir/lib" "$repo_dir/test"
cat >"$repo_dir/lib/gf-archive-bucket-demo.ts" <<'TS'
import { Construct } from 'constructs';
export class GfArchiveBucketDemo extends Construct {}
TS
cat >"$repo_dir/test/gf-archive-bucket-demo.test.ts" <<'TS'
test('placeholder', () => { expect(true).toBe(true); });
TS
git -C "$repo_dir" add lib/gf-archive-bucket-demo.ts test/gf-archive-bucket-demo.test.ts
issue_title='G1 greenfield: VersionedArchiveBucket 20260624-000339'
issue_body='Greenfield L3 — add new files only. Do not modify lib/sample-stack.ts.

## Deliverables
1. lib/gf-archive-bucket-demo.ts — export construct
2. test/gf-archive-bucket-demo.test.ts — Jest test'
jq -n \
  --arg title "$issue_title" \
  --arg body "$issue_body" \
  '{issue_details: {number: 5, title: $title, body: $body}, issue_or_pr_number: "5"}' \
  >"$work_root/notes.json"
gf_pr_out="$(GIT_TOKEN=fake CDKBOT_ALLOW_DIRECT=1 CDKBOT_SKIP_ISSUE_FETCH=1 bash "${ROOT}/scripts/stage-runner.sh" commit-pr "$work_root" 'sks/cdk-typescript-demo' '5' '' 'main' 2>&1)" || true
if ! test -s "$work_root/.work/pr-body.md"; then
  echo "FAIL: greenfield commit-pr should write pr-body.md: $gf_pr_out" >&2
  exit 1
fi
grep -q 'VersionedArchiveBucket' "$work_root/.work/pr-body.md"
grep -q 'CDK validation' "$work_root/.work/pr-body.md"
grep -q 'Deliverables (from issue)' "$work_root/.work/pr-body.md"
git -C "$repo_dir" log -1 --format=%s | grep -q 'VersionedArchiveBucket construct'
if grep -q 'Terraform resources' "$work_root/.work/pr-body.md"; then
  echo "FAIL: greenfield CDK PR body must not use Terraform template" >&2
  exit 1
fi

echo "commit-pr ignores WORKING_BRANCH spawn placeholder (trace 30cad5fbade9)"
wr_parent="$(mktemp -d)"
work_root="$wr_parent/.wf-commit-pr"
repo_dir="$work_root/repo"
mkdir -p "$repo_dir"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@test.com"
git -C "$repo_dir" config user.name "test"
echo "x" >"$repo_dir/README.md"
git -C "$repo_dir" add README.md
git -C "$repo_dir" commit -q -m "init"
echo "change" >>"$repo_dir/README.md"
commit_out="$(WORKING_BRANCH='<working_branch from notes or empty>' GIT_TOKEN=fake CDKBOT_ALLOW_DIRECT=1 bash "${ROOT}/scripts/stage-runner.sh" commit-pr "$work_root" 'org/repo' '1' '' 'main' 2>&1)" || true
if printf '%s' "$commit_out" | grep -q 'invalid reference'; then
  echo "FAIL: commit-pr used invalid branch name: $commit_out" >&2
  exit 1
fi
current_branch="$(git -C "$repo_dir" branch --show-current)"
case "$current_branch" in
  cdk-bot/*) ;;
  *)
    echo "FAIL: commit-pr should switch to generated cdk-bot branch, got '$current_branch' (output: $commit_out)" >&2
    exit 1
    ;;
esac

echo "OK: stage_runner_logic_test"
