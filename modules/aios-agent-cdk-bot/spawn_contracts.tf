# Per-stage subagent spawn contracts (bound on stage bindings at deploy time).
# Runtime resolves {{workflow_run_id}}, {{work_root}}, and {{stage_note_var:NAME}} from binding notes.

locals {
  shell_execute_series_working_dir_rule = "commands[0].working_dir=${local.shell_work_home} or omit — NEVER {{work_root}} or $HOME/.wf-* (host chdirs before the command; clone-pack creates WORK_ROOT)."

  shell_execute_series_shell_dollar_rule = <<-EOT
Shell runner execute_series: use single $ for variables ($PD, $CDKBOT_CLONE_PACK_B64, $WORK_ROOT, $REPO_CLONE_URL). NEVER $$ before a name — bash expands $$ to the shell PID (e.g. $$CDKBOT_CLONE_PACK_B64 → 359CDKBOT_…), which causes base64: invalid input even when CDKBOT_*_B64 env is set. Copy spawn-context command lines verbatim; do not re-escape for Terraform.
Subprocess env (trace eed7f3b6): `VAR=value; pack_ensure && other-script` does NOT export VAR to other-script — the child is a new process. ALWAYS repeat `VAR=value` immediately before each subprocess: `pack_ensure && VAR=value VAR2=value2 script.sh args…`. Positional argv to stage-runner.sh is preferred when documented (validate, prepare-implement-edits, commit-pr, clone-pack).
Env scoping: semicolon after inline assignments sets shell vars for the rest of the sh -c script only — not for child processes unless prefixed on the child command line.
Path scoping: agents often paste quoted `'$HOME/.wf-*'` instead of `{{work_root}}` (trace b9401899c86d). stage-runner normalizes literal `$HOME`/`$${HOME}` tokens; still copy spawn-header `{{work_root}}` verbatim in script args.
Integration MCP blocks bare `export`, `set`, `env`, and `printenv` in execute_series (trace 2f0357dbee47). Remote runner allows normal bash — still prefer inline VAR=value prefix on each subprocess invocation.
EOT

  cdk_spawn_context_header = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
ABS_WORK_ROOT: {{work_root}}
shell_work_home: ${local.shell_work_home}
execute_series_working_dir: ${local.shell_work_home}
CDKBOT_PACK_DIR: ${local.cdkbot_pack_dir}
CDKBOT_CLONE_PACK_SHA256: ${local.script_pack_clone_sha256}
CDKBOT_STAGE_RUNNER_SHA256: ${local.script_pack_runner_sha256}
script_pack_version: ${local.script_pack_version}
${local.shell_execute_series_shell_dollar_rule}
EOT

  cdk_spawn_context_clone = <<-EOT
${local.cdk_spawn_context_header}
Clone command — COPY VERBATIM (trace 0bf8c7ef — substitute read_notes values as literal argv; never REPO_CLONE_URL=… var indirection):
  CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/clone-pack.sh clone '{{work_root}}' '<repository_clone_url from read_notes>' '<repository_default_branch>' '<issue_or_pr_number>'
Example after read_notes: … clone '{{work_root}}' 'https://github.com/org/repo.git' 'main' '42' — four literal single-quoted args after clone; NOT clone '…' '$REPO_CLONE_URL' '$DEFAULT_BRANCH' '$ISSUE_OR_PR'.
On cdkbot_pack_error=: note clone_blocker=missing_script_pack (tofu apply to refresh runner script-pack secret, then restart aiden-runner for secrets sync — Docker rebuild not required for script-only changes). On clone_blocker=unexpanded_shell_var: re-run with spawn-context line above — literal URL/branch/issue argv only. On base64: invalid input when CDKBOT_*_B64 lengths are non-zero in env: note clone_blocker=wrong_shell_dollar_escape ($$ misuse — fix command to single $). Do NOT ad-hoc git clone / x-access-token HTTPS / gh repo clone (§8(g)).
Stale work root (trace 9e8afbe42c8d): if read_notes repo_clone_path is set but is NOT under current {{work_root}}/ (prior workflow run), IGNORE that path and still run clone into {{work_root}}/repo. Required success stdout includes repo_clone_path={{work_root}}/repo.
Check command (optional before clone when unsure): CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh check-work-root-clone '{{work_root}}' — repo_clone_ready=true means skip clone; clone_blocker=stale_repo_clone_path or repo_missing means run Clone command above.
FORBIDDEN in commands[0].command: REPO_CLONE_URL='…'; DEFAULT_BRANCH='…'; semicolon then clone-pack with '$REPO_CLONE_URL' args (single quotes block expansion); hardcoding /pack/20260616.* paths (use spawn CDKBOT_PACK_DIR only); skipping pack ensure prefix; CLONE_ONE_LINER; bare tfbot-ensure-pack; printf '%s' '<base64>' | base64 -d; $$PD / $$CDKBOT_* / $$WORK_ROOT (PID expansion); TRIGGER_JSON='{"..."}' (nested quotes break sh -c); truncating the command; WORK_ROOS typo (must be WORK_ROOT); manual git clone when pack missing.
EOT

  cdk_spawn_context_validate = <<-EOT
${local.cdk_spawn_context_header}
Validate-only command (checks only — PR is opened in edit stage via commit-pr; never validate-and-pr here):
  CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh validate '{{work_root}}' '{{work_root}}/repo'
FORBIDDEN: validate-and-pr; commit-pr; VALIDATE_ONE_LINER; printf '%s' '<base64>' | base64 -d; $$PD / $$CDKBOT_* (bash PID expansion); TRIGGER_JSON='{"..."}' inline; TRIGGER_JSON_B64 placeholder; pasting ---BEGIN VALIDATE_EXECUTE_SERIES--- body into commands[0].command; truncating the command; returning prose about "environment enumeration" without execute_series stdout.
Stdout MUST include fmt_exit= and module_quality_summary= from validate-cdk.sh (real shell — not synthesized). pr_url/working_branch come from read_notes (edit stage commit-pr).
EOT

  cdk_spawn_context_resolve_paths = <<-EOT
${local.cdk_spawn_context_header}
Resolve-paths command (detect CDK app vs Terraform module — run before implement routing):
  CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh resolve-paths '{{work_root}}' '{{work_root}}/repo' '<repository_default_branch from read_notes>' '<comma-separated hints from issue_details.body — optional>'
Use spawn-header {{work_root}} verbatim in resolve-paths args — NEVER paste quoted '$HOME/.wf-*' (literal $HOME breaks notes.json; trace b9401899c86d).
Stdout MUST include module_resolution_confidence=, module_paths=, and repo_kind= (cdk_app when cdk.json present). FORBIDDEN: find *.tf on CDK repos; registry.terraform.io; resolve-module-path subagent name.
EOT

  cdk_spawn_context_implement_app = <<-EOT
${local.cdk_spawn_context_header}
Implement-app uses EXACTLY TWO execute_series plus ONE create_files between them (trace f481e55e/84fa1c68 — NEVER cat >"$EDIT_SH" << heredoc inside execute_series; JSON escapes \\n → cat: invalid option). COPY commands VERBATIM — never reconstruct pack ensure or hardcode pack/20260616.* paths.

Series 1 — scaffold edit script path (commands.length=1 timeout 120):
  CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh prepare-implement-edits '{{work_root}}' '{{work_root}}/repo'

Between series 1 and 2 — ONE ${local.shell_tool_prefix}_create_files:
  Overwrite edit_script= path from series 1 stdout with a complete bash script (shebang, set -euo pipefail, cd module_paths, real sed/tee/cp edits from issue_details.body + preflight listings). FORBIDDEN: inline heredoc in execute_series; literal \\n characters; stub-only true; sed range addresses (/,/}/); cat <<EOF inside the script (trace f7a79c2a — unclosed quotes cause bash "EOF: No such file or directory").

Example create_files when issue body mentions KMS on lib/*.ts (adapt paths from issue_details.body):
  #!/usr/bin/env bash
  set -euo pipefail
  cd {{work_root}}/repo
  STACK=lib/sample-stack.ts
  TEST=test/sample-stack.test.ts
  sed -i.bak 's/s3\.BucketEncryption\.S3_MANAGED/s3.BucketEncryption.KMS_MANAGED/g' "$STACK"
  rm -f "$${STACK}.bak"
  sed -i.bak "s/SSEAlgorithm: 'AES256'/SSEAlgorithm: 'aws:kms'/g" "$TEST"
  rm -f "$${TEST}.bak"

If series 2 stdout truncates before implement_edit_verified=true, ONE follow-up execute_series (commands.length=1 timeout 30):
  CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && WR="$(CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh normalize-work-root '{{work_root}}')" && CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh read-implement-markers "$WR"

Webhook issue_details (trace 1b402e2a, f7a79c2a): read_notes issue_details — title/body/number come from the incoming webhook (clone stage). When issue_details.body names paths (e.g. lib/sample-stack.ts), create_files MUST edit those paths. FORBIDDEN: ask_clarifying_question; create_agent for clarification; prose asking the operator for "specific instructions" or "more details" when issue_details.body is non-empty. On implement_blocker=no_file_edits or edit_script_syntax_error or edit_script_failed: retry create_files with simple sed substitution then series 2 — never ask the user.

Series 2 — run pipeline (commands.length=1 timeout 900):
  CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && WR="$(CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh normalize-work-root '{{work_root}}')" && EDIT_SH="$WR/.work/implement-edits.sh" && [ -n "$EDIT_SH" ] && [ -f "$EDIT_SH" ] || { echo implement_blocker=edit_script_missing path=$EDIT_SH; exit 1; } && CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh implement-app-run '{{work_root}}/repo' "$EDIT_SH" 'short_one_line_summary_words_only'

FORBIDDEN: cat >"\$EDIT_SH" << in execute_series (trace f481e55e); commands.length>1 in series 1; skipping create_files; angle-bracket placeholder text in commands; literal '<module_paths from read_notes>' (trace 55b8fb232345); WORK_ROOT= before semicolon; prepare-implement-edits without '{{work_root}}' and module_paths argv; stage-runner.sh subprocess without CDKBOT_ALLOW_DIRECT=1 prefix; hardcoding /pack/20260616.* paths; single-quoted paths containing $HOME; rg with full issue title or body text (trace 933de8722d8d); Phase markdown; load_skill; third execute_series; find *.tf on CDK apps.
REQUIRED stdout from series 2: implement_preflight_ok=true, implement_edit_verified=true, cdk_language=, implement_summary=, and when GIT_TOKEN/gh is configured also pr_url= + working_branch= (implement-app-run auto commit-pr — trace 57f727366edf). When pr_url is already in read_notes after series 2, architect MUST skip create-pr-runner (dedup poison) and set stage_summary:implement-cdk=done.
EOT

  cdk_spawn_context_commit_pr = <<-EOT
${local.cdk_spawn_context_header}
Commit-pr command — COPY VERBATIM as FIRST ${local.shell_tool_prefix}_execute_series (trace 2c708b834ca1: read_notes before commit-pr burned budget and never opened the PR). Substitute from create_agent context (architect passes repository_full_name, issue_or_pr_number, repository_default_branch — do NOT read_notes first):
  CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh commit-pr '{{work_root}}' '<repository_full_name from context>' '<issue_or_pr_number from context>' '' '<repository_default_branch from context>'
Rework loop only: when create_agent context includes working_branch=, prefix WORKING_BRANCH='<literal branch from context>' immediately before stage-runner — paste the actual branch name, never angle-bracket placeholder text (trace 30cad5fbade9: fatal: invalid reference).
FORBIDDEN: read_notes or note before execute_series; WORKING_BRANCH='<working_branch from notes or empty>'; pasting ---BEGIN COMMIT_PR_EXECUTE_SERIES--- without commit-pr '{{work_root}}' argv; never export WORK_ROOT=; COMMIT_PR_ONE_LINER; $$ before WORK_ROOT/REPO_FULL_NAME.
Stdout MUST include working_branch= and pr_url= on success; pr_error=nothing_to_commit when no staged diff.
EOT

  cdk_spawn_context_discovery_scaffold = <<-EOT
${local.cdk_spawn_context_header}
Discovery command (short — invoke pack runner like clone-pack; never "$WORK_ROOT/.pack/..."):
  CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && ISSUE_TITLE='<issue_details.title from read_notes>' ISSUE_BODY='<issue_details.body>' ISSUE_OR_PR='<issue_or_pr_number>' CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/stage-runner.sh catalog-scaffold '{{work_root}}'
Optional overrides: MODULE_DIR='…' PROVIDER_ROOT='aws|azurerm|gcp' SIBLING_DIR='…'
ISSUE_TITLE/ISSUE_OR_PR are required when TRIGGER_JSON_B64 is omitted or invalid (stage-runner infers MODULE_DIR from title). Copy values from read_notes — never placeholder angle-bracket text.
If spawn header WORK_ROOT shows $HOME/.wf-*: still use command above — stage-runner expands $HOME; prefer repo_clone_path parent from clone stdout when noting paths.
FORBIDDEN: WORK_ROOT='$HOME/.wf-*' only when paired with "$WORK_ROOT/.pack/stage-runner.sh"; $$PD / $$CDKBOT_* (bash PID expansion); TRIGGER_JSON='{"..."}' inline; TRIGGER_JSON_B64='<base64 you computed…>' placeholder; DISCOVERY_SCAFFOLD_ONE_LINER; truncating the command.
EOT

  # Minimal shared context for GitHub-only subagents and planner stages.
  cdk_spawn_context = local.cdk_spawn_context_header

  cdk_spawn_context_progress_comment = join("\n\n", [
    local.cdk_spawn_context_header,
    <<-EOT
Progress comment command (env vars + pack script — NEVER inline /bin/bash <<'CDKBOT_PROGRESS' heredoc; trace $$ → PID breaks mktemp/gh):
  CDKBOT_MODULE_PREFIX='${local.module_prefix}' CDKBOT_ALLOW_DIRECT=1; ${local.cdkbot_pack_ensure_shell} && REPO_FULL_NAME='<repository_full_name>' ISSUE_OR_PR='<issue_or_pr_number>' PROGRESS_COMMENT_ID='<progress_comment_id or empty>' PROGRESS_intake='<done|running|blocked|pending|skipped>' PROGRESS_implement='<…>' PROGRESS_validate='<…>' PROGRESS_pr='<…>' PROGRESS_DETAIL='<short status paragraph>' CDKBOT_ALLOW_DIRECT=1 ${local.cdkbot_pack_dir}/progress-comment.sh
FORBIDDEN: pasting progress-comment-execute-series heredoc; $$ before variable names (bash PID expansion — e.g. $$BODY_FILE → 22BODY_FILE); bare export/set as first token.
Stdout MUST include progress_comment_id= and progress_comment_exit=0 on success.
EOT
  ])

  spawn_contract_create_pr_notify = {
    sub_agent_name = "create-pr-notify"
    task_type      = "efficiency"
    tool_names = [
      "${local.shell_tool_prefix}_execute_command",
      "${local.shell_tool_prefix}_execute_series",
      "note",
      "read_notes",
    ]
    max_llm_calls       = 5
    max_tool_iterations = 42
    timeout_seconds     = local.subagent_budgets.github_timeout_seconds
    goal                = "Blocked/max-iter notify ONLY. When progress_comment_id is set: skip — architect spawns progress-comment-updater (Template P) with PROGRESS_pr=blocked and blocker in PROGRESS_DETAIL. Else ONE ${local.shell_tool_prefix}_execute_series: single gh issue comment (Template E). Paste repository_full_name, issue_or_pr_number, blocker text from stage_summary notes. FORBIDDEN: create-pr-runner, load_skill, read_notes loops, create-pr-evidence-submit (architect uses submit_evidence). Stop after comment succeeds."
    context             = local.cdk_spawn_context
  }

  spawn_contract_create_pr_comment = {
    sub_agent_name = "create-pr-comment"
    task_type      = "efficiency"
    tool_names = [
      "${local.shell_tool_prefix}_execute_command",
      "${local.shell_tool_prefix}_execute_series",
      "note",
      "read_notes",
    ]
    max_llm_calls       = local.subagent_budgets.github_max_llm_calls
    max_tool_iterations = 42
    timeout_seconds     = local.subagent_budgets.github_timeout_seconds
    goal                = "When progress_comment_id is set in notes: do NOT POST a new issue comment — architect uses progress-comment-updater (Template P) instead. Else ONE ${local.shell_tool_prefix}_execute_series with a single gh issue comment (Template E). Paste repository_full_name, issue_or_pr_number, blocker text from stage_summary notes. FORBIDDEN: gh auth token/login, read_notes loops, env probes. Stop after comment succeeds."
    context             = local.cdk_spawn_context
  }

  spawn_contract_progress_comment = {
    sub_agent_name = "progress-comment-updater"
    task_type      = "terminal_calling"
    tool_names = [
      "${local.shell_tool_prefix}_execute_command",
      "${local.shell_tool_prefix}_execute_series",
      "note",
      "read_notes",
    ]
    max_llm_calls       = 8
    max_tool_iterations = 42
    timeout_seconds     = local.subagent_budgets.github_timeout_seconds
    goal                = <<-EOT
GitHub-only live progress comment (Template P). Max 3 tools: read_notes, ONE ${local.shell_tool_prefix}_execute_series, note.
read_notes: repository_full_name, issue_or_pr_number, progress_comment_id, stage_summary:clone, stage_summary:implement-cdk, stage_summary:validate, module_quality_summary, pr_url, clone_blocker, gate_result, test_summary_tail.
Map PROGRESS_* marks per orchestration §3j (done|running|blocked|pending|skipped). PROGRESS_DETAIL: one short paragraph (pr_url, module_quality_summary, blocker, or test_summary_tail excerpt ≤400 chars).
ONE execute_series commands.length=1 timeout_seconds=90. Command MUST be spawn-context Progress comment line (inline REPO_FULL_NAME=, ISSUE_OR_PR=, PROGRESS_* vars, CDKBOT_MODULE_PREFIX, semicolon before pack ensure, then progress-comment.sh — NEVER heredoc, NEVER $$).
When progress_comment_id empty → POST (script emits progress_comment_id=). When set → PATCH same comment only.
note progress_comment_id and progress_comment_url from stdout. FORBIDDEN: Ubuntu tools, load_skill, second execute_series, gh issue comment POST when progress_comment_id already set, inventing comment id.
EOT
    context             = local.cdk_spawn_context_progress_comment
  }

  spawn_contracts_check_info_and_clone = [
    {
      sub_agent_name = "clone-fetch"
      task_type      = "efficiency"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.github_max_llm_calls
      max_tool_iterations = 42
      timeout_seconds     = local.subagent_budgets.github_timeout_seconds
      goal                = "ONLY when webhook JSON lacked issue.title/pull_request.title. ONE gh api call for issue/PR metadata. FORBIDDEN: gh auth token, gh repo list, gh api /user/repos, env probes. note issue_details JSON. Stop."
      context             = local.cdk_spawn_context
    },
    {
      sub_agent_name = "clone-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.runner_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. Clone ONLY — max 2 tools: read_notes then ONE ${local.shell_tool_prefix}_execute_series. read_notes repository_clone_url repository_default_branch issue_or_pr_number. execute_series commands.length=1 timeout 300. ${local.shell_execute_series_working_dir_rule} ${local.shell_execute_series_shell_dollar_rule} COPY spawn-context Clone command VERBATIM (trace 0bf8c7ef): paste read_notes URL/branch/issue as literal single-quoted clone-pack argv — '{{work_root}}' 'https://…git' 'main' '1'; include full pack-ensure prefix from spawn context; NEVER REPO_CLONE_URL=… semicolon pattern; NEVER clone-pack args '$REPO_CLONE_URL' / '$DEFAULT_BRANCH' / '$ISSUE_OR_PR'; NEVER hardcode pack/20260616.* paths; NEVER export/set as first token; single $ only — NEVER $$). Stale read_notes repo_clone_path from a prior .wf-* run (trace 9e8afbe42c8d): if path is not under {{work_root}}/ OR {{work_root}}/repo/.git is missing, run clone anyway — never skip clone because an older workflow left repo_clone_path set. On cdkbot_pack_error=: clone_blocker=missing_script_pack. On clone_blocker=unexpanded_shell_var: retry with literal argv from read_notes. On base64 invalid input with TFBOT env set: clone_blocker=wrong_shell_dollar_escape. On command blocked environment enumeration: clone_blocker=shell_runner_incompatible. NEVER git clone/x-access-token HTTPS/gh repo clone (§8(g)). NEVER CLONE_ONE_LINER, inline base64 decode, TRIGGER_JSON inline, truncate, load_skill, _embed_cdkbot_run, example.com, fake repo_head_sha. note repo_clone_path stage_runner_path repo_head_sha script_pack_version from stdout only; repo_clone_path MUST be {{work_root}}/repo on success. Stop — do not summarize clone in prose without tool output."
      context             = local.cdk_spawn_context_clone
    },
  ]

  spawn_contracts_implement_module = [
    {
      sub_agent_name = "implement-cdk-resolve-paths"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.runner_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. read_notes repository_clone_path repository_default_branch issue_details. FIRST TOOL MUST be ${local.shell_tool_prefix}_execute_series (never load_skill) with spawn-context Resolve-paths command. ONE execute_series commands.length=1 timeout 300. ${local.shell_execute_series_working_dir_rule} ${local.shell_execute_series_shell_dollar_rule} note repo_kind module_paths module_resolution_confidence cdk_language cdk_app_root from stdout only. FORBIDDEN: resolve-module-path, find *.tf when repo has cdk.json, registry.terraform.io, load_skill, multiple execute_series."
      context             = local.cdk_spawn_context_resolve_paths
    },
    {
      sub_agent_name = "implement-cdk-app-update"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "${local.shell_tool_prefix}_create_files",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.implement_max_llm_calls
      max_tool_iterations = 48
      timeout_seconds     = local.subagent_budgets.implement_timeout_seconds
      goal                = "CDK application repo (repo_kind=cdk_app or cdk.json in clone). read_notes repo_clone_path module_paths issue_details issue_or_pr_number. Webhook already supplied issue title/body — issue_details is authoritative; extract target file paths from issue_details.body (e.g. lib/*.ts) and preflight --- file: listings. EXACTLY TWO ${local.shell_tool_prefix}_execute_series plus ONE ${local.shell_tool_prefix}_create_files (never load_skill) per spawn-context Implement-app — trace f481e55e, 84fa1c68, fd3d69cf, b9401899c86d, eed7f3b6, 1b402e2a, f7a79c2a, 9e8afbe42c8d. COPY Series 1 and Series 2 commands VERBATIM. Series 2 MODULE_PATH is always '{{work_root}}/repo' from spawn context — never a repo_clone_path from a prior workflow under a different .wf-* directory. After Series 1 stdout edit_script=: ONE create_files overwriting that path with real bash edits (simple sed -i.bak substitution preferred over sed range /,/}/) — NEVER cat heredoc inside execute_series or inside the edit script; NEVER leave scaffold-only true. Series 2: implement-app-run with double-quoted EDIT_SH. ${local.shell_execute_series_working_dir_rule} ${local.shell_execute_series_shell_dollar_rule} Every stage-runner.sh subprocess MUST be prefixed CDKBOT_ALLOW_DIRECT=1. note module_paths cdk_language implement_summary implement_edit_verified from series 2 stdout only. If series 2 stdout has implement_blocker=edit_script_syntax_error or edit_script_failed: rewrite create_files using spawn-context KMS sed example — do NOT ask the user. If implement_blocker=no_file_edits: you skipped create_files or wrote a no-op script — fix create_files from issue_details.body and re-run series 2. If series 2 stdout lacks implement_summary= or implement_edit_verified=true, note implement_blocker=missing_implement_markers. Coordinator retry: spawn as implement-cdk-app-update-retry (not duplicate implement-cdk-app-update — Guild spawn dedup). FORBIDDEN: ask_clarifying_question; create_agent for clarification; prose asking operator to provide instructions/details when issue_details.body present; cat >\"\\$EDIT_SH\" << in execute_series; literal \\\\n in shell commands; skipping create_files; WORK_ROOT= before semicolon; mkdir/cat on single-quoted work_root paths; pasting spawn-context placeholder prose into shell; rg with issue title/body as pattern (trace 933de8722d8d); single-series inline edits; export/set as first token; Phase markdown; prose success without tool stdout; terraform/tofu/*.tf; registry.terraform.io; find *.tf; implement-cdk-registry-wrap; load_skill; third execute_series; validate-runner."
      context             = local.cdk_spawn_context_implement_app
    },
    {
      sub_agent_name = "implement-cdk-catalog-scaffold"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.runner_max_llm_calls
      max_tool_iterations = 48
      timeout_seconds     = local.subagent_budgets.runner_timeout_seconds + 300
      goal                = "ABS_WORK_ROOT={{work_root}}. read_notes module_paths module_quality_rework module_quality_gaps test_summary_tail issue_details issue_or_pr_number. If module_quality_rework=true and module_paths set: REWORK ONLY — shell-fix gaps under module_paths[0], then spawn-context Validate (MODULE_PATH=module_paths[0]); do NOT greenfield catalog-scaffold. Else greenfield: FIRST TOOL MUST be ${local.shell_tool_prefix}_execute_series (never load_skill) with spawn-context Discovery command. ONE execute_series commands.length=1 timeout 900. ${local.shell_execute_series_working_dir_rule} ${local.shell_execute_series_shell_dollar_rule} Single $ only — NEVER $$ before TFBOT/WORK_ROOT. NEVER .pack under WORK_ROOT, TRIGGER_JSON inline, placeholder TRIGGER_JSON_B64. Stdout MUST include fmt_exit= module_quality_summary= (and catalog_greenfield_validated=true on greenfield). note module_paths validate_markers_file test_summary_tail module_quality_gaps from stdout. FORBIDDEN: load_skill, validate-runner, create-pr-*, planner goals with pasted heredocs, multiple execute_series."
      context             = local.cdk_spawn_context_discovery_scaffold
    },
  ]

  spawn_contracts_validate = [
    {
      sub_agent_name = "validate-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.validate_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.validate_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. FIRST TOOL CALL MUST be ${local.shell_tool_prefix}_execute_series (never load_skill). read_notes for module_paths repo_clone_path pr_url working_branch. ONE execute_series commands.length=1 timeout_seconds=600. ${local.shell_execute_series_working_dir_rule} ${local.shell_execute_series_shell_dollar_rule} Command MUST match spawn-context Validate-only command (stage-runner validate — single $ only). NEVER validate-and-pr; NEVER VALIDATE_ONE_LINER; NEVER TRIGGER_JSON inline; NEVER $$ before PD/TFBOT/WORK_ROOT. NEVER return success prose without execute_series stdout containing fmt_exit=. Note fmt_exit init_exit validate_exit test_exit lint_exit synth_exit cfnlint_exit nag_exit module_quality_summary validate_markers_file test_summary_tail module_quality_gaps from stdout (quote test_summary_tail when test_exit=1). Preserve pr_url working_branch pr_draft from read_notes — validate does NOT open or update PRs. FORBIDDEN: printf fake PASS, load_skill, implement-cdk-*, create-pr-runner, create-pr-evidence-submit, custom validate scripts, environment enumeration prose without tool output."
      context             = local.cdk_spawn_context_validate
    },
  ]

  spawn_contracts_commit_pr = [
    {
      sub_agent_name = "create-pr-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
      ]
      max_llm_calls       = local.create_pr_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.runner_timeout_seconds + local.subagent_budgets.github_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. Edit-stage commit+push+PR (open draft PR after code changes; on rework push to same branch). FIRST TOOL CALL MUST be ${local.shell_tool_prefix}_execute_series (never load_skill, never read_notes, never note before execute_series — trace 2c708b834ca1). Substitute repository_full_name, issue_or_pr_number, repository_default_branch from create_agent context. ONE execute_series commands.length=1 timeout_seconds=600 with spawn-context Commit-pr command. ${local.shell_execute_series_working_dir_rule} ${local.shell_execute_series_shell_dollar_rule} Rework: when context includes working_branch=, prefix WORKING_BRANCH='<literal branch>' before stage-runner (reuse branch — never open second PR). stage-runner commit-pr always runs (push-only when branch/PR already exist). AFTER execute_series stdout: note working_branch pr_url pr_title pr_draft pr_error from stdout only. When pr_url newly set and progress_comment_id empty in context → optional ONE gh issue comment with PR link. If progress_comment_id set in context → skip issue comment (architect uses progress-comment-updater). Coordinator: skip spawning create-pr-runner when read_notes already has pr_url after implement-app-run (trace spawn-dedup); use create-pr-runner-retry on rework loops only. FORBIDDEN: load_skill; read_notes; prep notes before commit-pr; skipping commit-pr execute_series because pr_url is set (rework must still push); second gh pr create; re-clone; export WORK_ROOT as first token."
      context             = local.cdk_spawn_context_commit_pr
    },
  ]

  spawn_contracts_validate_followup = [
    local.spawn_contract_create_pr_notify,
    local.spawn_contract_create_pr_comment,
  ]

  # Backward-compatible alias for tests/docs that referenced validate-stage PR wiring.
  spawn_contracts_create_pr = concat(local.spawn_contracts_commit_pr, local.spawn_contracts_validate_followup)
}
