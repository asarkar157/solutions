# Per-stage subagent spawn contracts (bound on stage bindings at deploy time).
# Runtime resolves {{workflow_run_id}}, {{work_root}}, and {{stage_note_var:NAME}} from binding notes.

locals {
  ubuntu_execute_series_working_dir_rule = "commands[0].working_dir=${local.ubuntu_integration_home} or omit — NEVER {{work_root}} or $HOME/.wf-* (host chdirs before the command; clone-pack creates WORK_ROOT)."

  ubuntu_execute_series_shell_dollar_rule = <<-EOT
Ubuntu execute_series shell: use single $ for variables ($PD, $TFBOT_CLONE_PACK_B64, $WORK_ROOT, $REPO_CLONE_URL). NEVER $$ before a name — bash expands $$ to the shell PID (e.g. $$TFBOT_CLONE_PACK_B64 → 359TFBOT_…), which causes base64: invalid input even when TFBOT_*_B64 env is set. Copy spawn-context command lines verbatim; do not re-escape for Terraform.
EOT

  terraform_spawn_context_header = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
ABS_WORK_ROOT: {{work_root}}
ubuntu_integration_home: ${local.ubuntu_integration_home}
execute_series_working_dir: ${local.ubuntu_integration_home}
TFBOT_PACK_DIR: ${local.tfbot_pack_dir}
TFBOT_CLONE_PACK_SHA256: ${local.script_pack_clone_sha256}
TFBOT_STAGE_RUNNER_SHA256: ${local.script_pack_runner_sha256}
script_pack_version: ${local.script_pack_version}
${local.ubuntu_execute_series_shell_dollar_rule}
EOT

  terraform_spawn_context_clone = <<-EOT
${local.terraform_spawn_context_header}
Clone command (short — inline ensure decodes pack from Ubuntu integration TFBOT_*_B64 env; recycle sidecar after tofu apply):
  export WORK_ROOT='{{work_root}}' REPO_CLONE_URL='<repository_clone_url from read_notes>' DEFAULT_BRANCH='<repository_default_branch>' ISSUE_OR_PR='<issue_or_pr_number>' TFBOT_ALLOW_DIRECT=1 && ${local.tfbot_pack_ensure_shell} && ${local.tfbot_pack_dir}/clone-pack.sh clone "$WORK_ROOT" "$REPO_CLONE_URL" "$DEFAULT_BRANCH" "$ISSUE_OR_PR"
On tfbot_pack_error=: note clone_blocker=missing_script_pack (recycle sidecar after tofu apply). On base64: invalid input when TFBOT_*_B64 lengths are non-zero in env: note clone_blocker=wrong_shell_dollar_escape ($$ misuse — fix command to single $). Do NOT ad-hoc git clone / x-access-token HTTPS / gh repo clone (§8(g)).
FORBIDDEN in commands[0].command: CLONE_ONE_LINER; bare tfbot-ensure-pack; printf '%s' '<base64>' | base64 -d; $$PD / $$TFBOT_* / $$WORK_ROOT (PID expansion); TRIGGER_JSON='{"..."}' (nested quotes break sh -c); truncating the command; WORK_ROOS typo (must be WORK_ROOT); manual git clone when pack missing.
EOT

  terraform_spawn_context_validate = <<-EOT
${local.terraform_spawn_context_header}
Validate command (short — pack ensure + stage-runner; never VALIDATE_ONE_LINER / inline TRIGGER_JSON):
  export WORK_ROOT='{{work_root}}' MODULE_PATH='<module_paths from read_notes — absolute path under repo_clone_path>' REPO_FULL_NAME='<repository_full_name>' ISSUE_OR_PR='<issue_or_pr_number>' BASE_BRANCH='<repository_default_branch>' DEFER_PR_UNTIL_PASS=${var.defer_pr_until_quality_pass ? "true" : "false"} TFBOT_ALLOW_DIRECT=1 && ${local.tfbot_pack_ensure_shell} && ${local.tfbot_pack_dir}/stage-runner.sh validate-and-pr
FORBIDDEN: VALIDATE_ONE_LINER; printf '%s' '<base64>' | base64 -d; $$PD / $$TFBOT_* (bash PID expansion); TRIGGER_JSON='{"..."}' inline; TRIGGER_JSON_B64 placeholder; pasting ---BEGIN VALIDATE_EXECUTE_SERIES--- body into commands[0].command; truncating the command.
Stdout MUST include fmt_exit= and module_quality_summary= from stage-runner (real shell — not synthesized).
EOT

  terraform_spawn_context_commit_pr = join("\n\n", [
    local.terraform_spawn_context_header,
    <<-EOT
---BEGIN COMMIT_PR_EXECUTE_SERIES---
${local.commit_pr_execute_series_body}
---END COMMIT_PR_EXECUTE_SERIES---
EOT
  ])

  terraform_spawn_context_discovery_scaffold = <<-EOT
${local.terraform_spawn_context_header}
Discovery command (short — invoke pack runner like clone-pack; never "$WORK_ROOT/.pack/..."):
  export WORK_ROOT='{{work_root}}' TFBOT_ALLOW_DIRECT=1 ISSUE_TITLE='<issue_details.title from read_notes>' ISSUE_BODY='<issue_details.body>' ISSUE_OR_PR='<issue_or_pr_number>' TRIGGER_JSON_B64='<optional: real base64 of minified webhook JSON>' && ${local.tfbot_pack_ensure_shell} && ${local.tfbot_pack_dir}/stage-runner.sh discovery-scaffold '{{work_root}}'
Optional overrides: MODULE_DIR='…' PROVIDER_ROOT='aws|azurerm|gcp' SIBLING_DIR='…'
ISSUE_TITLE/ISSUE_OR_PR are required when TRIGGER_JSON_B64 is omitted or invalid (stage-runner infers MODULE_DIR from title). Copy values from read_notes — never placeholder angle-bracket text.
If spawn header WORK_ROOT shows $HOME/.wf-*: still use command above — stage-runner expands $HOME; prefer repo_clone_path parent from clone stdout when noting paths.
FORBIDDEN: WORK_ROOT='$HOME/.wf-*' only when paired with "$WORK_ROOT/.pack/stage-runner.sh"; $$PD / $$TFBOT_* (bash PID expansion); TRIGGER_JSON='{"..."}' inline; TRIGGER_JSON_B64='<base64 you computed…>' placeholder; DISCOVERY_SCAFFOLD_ONE_LINER; truncating the command.
EOT

  # Minimal shared context for GitHub-only subagents and planner stages.
  terraform_spawn_context = local.terraform_spawn_context_header

  spawn_contract_create_pr_notify = {
    sub_agent_name = "create-pr-notify"
    task_type      = "efficiency"
    tool_names = [
      "${local.github_tool_prefix}_execute_command",
      "${local.github_tool_prefix}_execute_series",
      "note",
      "read_notes",
    ]
    max_llm_calls       = local.subagent_budgets.github_notify_max_llm_calls
    max_tool_iterations = 42
    timeout_seconds     = local.subagent_budgets.github_comment_timeout_seconds
    goal                = "Blocked/max-iter notify ONLY. ONE ${local.github_tool_prefix}_execute_series: single gh issue comment (Template E). Paste repository_full_name, issue_or_pr_number, blocker text from stage_summary notes. FORBIDDEN: Ubuntu tools, create-pr-runner, load_skill, read_notes loops, create-pr-evidence-submit (architect uses submit_evidence). Stop after comment succeeds."
    context             = local.terraform_spawn_context
  }

  spawn_contract_create_pr_comment = {
    sub_agent_name = "create-pr-comment"
    task_type      = "efficiency"
    tool_names = [
      "${local.github_tool_prefix}_execute_command",
      "${local.github_tool_prefix}_execute_series",
      "note",
      "read_notes",
    ]
    max_llm_calls       = local.subagent_budgets.github_comment_max_llm_calls
    max_tool_iterations = 42
    timeout_seconds     = local.subagent_budgets.github_comment_timeout_seconds
    goal                = "ONE ${local.github_tool_prefix}_execute_series with a single gh issue comment (Template E). Paste repository_full_name, issue_or_pr_number, and blocker text from stage_summary notes. FORBIDDEN: Ubuntu tools, gh auth token/login, read_notes loops, env probes. Stop after comment succeeds."
    context             = local.terraform_spawn_context
  }

  spawn_contracts_check_info_and_clone = [
    {
      sub_agent_name = "check-info-and-clone-fetch"
      task_type      = "efficiency"
      tool_names = [
        "${local.github_tool_prefix}_execute_command",
        "${local.github_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.github_fetch_max_llm_calls
      max_tool_iterations = 42
      timeout_seconds     = local.subagent_budgets.github_fetch_timeout_seconds
      goal                = "ONLY when webhook JSON lacked issue.title/pull_request.title. ONE gh api call for issue/PR metadata. FORBIDDEN: gh auth token, gh repo list, gh api /user/repos, env probes. note issue_details JSON. Stop."
      context             = local.terraform_spawn_context
    },
    {
      sub_agent_name = "check-info-and-clone-clone"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.script_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. Clone ONLY — max 2 tools: read_notes then ONE ${local.ubuntu_tool_prefix}_execute_series. read_notes repository_clone_url repository_default_branch issue_or_pr_number. execute_series commands.length=1 timeout 300. ${local.ubuntu_execute_series_working_dir_rule} ${local.ubuntu_execute_series_shell_dollar_rule} Command MUST be spawn-context Clone (export WORK_ROOT=… REPO_CLONE_URL=… DEFAULT_BRANCH=… ISSUE_OR_PR=… TFBOT_ALLOW_DIRECT=1 + pack ensure + clone-pack.sh clone; single $ only — NEVER $$). On tfbot_pack_error=: clone_blocker=missing_script_pack. On base64 invalid input with TFBOT env set: clone_blocker=wrong_shell_dollar_escape. NEVER git clone/x-access-token HTTPS/gh repo clone (§8(g)). NEVER CLONE_ONE_LINER, inline base64 decode, TRIGGER_JSON inline, truncate, load_skill, _embed_tfbot_run, example.com, fake repo_head_sha. note repo_clone_path stage_runner_path repo_head_sha script_pack_version from stdout only."
      context             = local.terraform_spawn_context_clone
    },
  ]

  spawn_contracts_implement_module = [
    {
      sub_agent_name = "implement-module-discovery-scaffold"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.script_runner_max_llm_calls
      max_tool_iterations = 48
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds + 300
      goal                = "ABS_WORK_ROOT={{work_root}}. read_notes module_paths module_quality_rework module_quality_gaps test_summary_tail issue_details issue_or_pr_number. If module_quality_rework=true and module_paths set: REWORK ONLY — shell-fix gaps under module_paths[0], then spawn-context Validate (MODULE_PATH=module_paths[0]); do NOT greenfield discovery-scaffold. Else greenfield: FIRST TOOL MUST be ${local.ubuntu_tool_prefix}_execute_series (never load_skill) with spawn-context Discovery command. ONE execute_series commands.length=1 timeout 900. ${local.ubuntu_execute_series_working_dir_rule} ${local.ubuntu_execute_series_shell_dollar_rule} Single $ only — NEVER $$ before TFBOT/WORK_ROOT. NEVER .pack under WORK_ROOT, TRIGGER_JSON inline, placeholder TRIGGER_JSON_B64. Stdout MUST include fmt_exit= module_quality_summary= (and discovery_greenfield_validated=true on greenfield). note module_paths validate_markers_file test_summary_tail module_quality_gaps from stdout. FORBIDDEN: load_skill, validate-and-test-runner, create-pr-*, implement-module-scaffold on discovery repos, planner goals with pasted heredocs, multiple execute_series."
      context             = local.terraform_spawn_context_discovery_scaffold
    },
    {
      sub_agent_name = "implement-module-registry-wrap"
      task_type      = "coding"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "${local.ubuntu_tool_prefix}_execute_parallel",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.hcl_author_max_llm_calls
      max_tool_iterations = 48
      timeout_seconds     = local.subagent_budgets.hcl_author_timeout_seconds
      goal                = "WORK_ROOT={{work_root}}. Search registry.terraform.io via curl+jq, write thin wrapper module under the clone, note module_paths and registry_wrap_summary. ONE bounded search series when possible."
      context             = local.terraform_spawn_context
    },
    {
      sub_agent_name = "implement-module-scaffold"
      task_type      = "coding"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.hcl_author_max_llm_calls
      max_tool_iterations = 48
      timeout_seconds     = local.subagent_budgets.hcl_author_timeout_seconds
      goal                = "WORK_ROOT={{work_root}}. Non-discovery repos ONLY (when discovery_repo is not true). Scaffold under repo_clone_path=$WORK_ROOT/repo via ONE execute_series shell writes. FORBIDDEN on discovery-modules repos. note module_paths, module_resolution_confidence=greenfield, scaffold_summary."
      context             = local.terraform_spawn_context
    },
  ]

  spawn_contracts_validate_and_test = [
    {
      sub_agent_name = "validate-and-test-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.validate_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.validate_runner_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. FIRST TOOL CALL MUST be ${local.ubuntu_tool_prefix}_execute_series (never load_skill). read_notes for module_paths repo_clone_path repository_full_name issue_or_pr_number repository_default_branch. ONE execute_series commands.length=1 timeout_seconds=600. ${local.ubuntu_execute_series_working_dir_rule} ${local.ubuntu_execute_series_shell_dollar_rule} Command MUST match spawn-context Validate command (single $ only). NEVER VALIDATE_ONE_LINER; NEVER TRIGGER_JSON inline; NEVER $$ before PD/TFBOT/WORK_ROOT. Note fmt_exit init_exit validate_exit test_exit pr_eligible_fmt_validate pr_url working_branch pr_draft module_quality_summary validate_markers_file test_summary_tail module_quality_gaps from stdout (quote test_summary_tail when test_exit=1). When pr_eligible_fmt_validate=true (fmt+init+validate), validate-and-pr opens draft PR even if tests fail. Copy pr_url pr_deferred= from stdout (reason string, not boolean true). Never when init_exit=1 or validate_exit=1. FORBIDDEN: printf fake PASS, load_skill, implement-module-*, create-pr-runner, create-pr-comment, create-pr-evidence-submit, custom validate scripts."
      context             = local.terraform_spawn_context_validate
    },
  ]

  spawn_contracts_create_pr = [
    local.spawn_contract_create_pr_notify,
    {
      sub_agent_name = "create-pr-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "${local.github_tool_prefix}_execute_command",
        "${local.github_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.create_pr_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds + local.subagent_budgets.github_comment_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. read_notes pr_url, working_branch, pr_title, pr_draft, test_summary_tail, repository_full_name, issue_or_pr_number. If pr_url already set → REQUIRED: ONE ${local.github_tool_prefix}_execute_series gh issue comment (PR link + test_summary_tail if present). Skip Ubuntu commit-pr. create-pr-register is OPTIONAL (skip when no STACKGEN_TOKEN). Else (1) ONE ${local.ubuntu_tool_prefix}_execute_series: export WORKING_BRANCH from notes when set; paste COMMIT_PR block (reuses branch, pushes to existing PR head). (2) ONE GitHub issue comment. FORBIDDEN: load_skill, second pr create when pr_url set, re-clone when working_branch on remote."
      context             = local.terraform_spawn_context_commit_pr
    },
    {
      sub_agent_name = "create-pr-register"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.script_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds
      goal                = "Optional StackGen registration when STACKGEN_TOKEN is set. WORK_ROOT={{work_root}}. Skip with note registration_skipped=missing_stackgen_token when unset."
      context             = local.terraform_spawn_context
    },
  ]
}
