# Per-stage create_agent contracts (Guild StageBinding.spawn_contracts).
# Runtime resolves {{workflow_run_id}} and {{work_root}} at execution time.

locals {
  terraform_spawn_context = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
module_prefix: ${local.module_prefix}
EOT

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
        "load_skill",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.script_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds
      goal                = "load_skill ${local.sop_workflow_script_pack}. ONE execute_series: copy script-pack §2.1 clone block verbatim (bash -lc + _embed_tfbot_run clone). WORK_ROOT={{work_root}}. Clone MUST land at $WORK_ROOT/repo via stage-runner — FORBIDDEN: ad hoc git clone to repo_clone, mkdir+clone without _embed_tfbot_run, directory listing. note repo_clone_path and repo_head_sha from stdout. Stop."
      context             = local.terraform_spawn_context
    },
    local.spawn_contract_create_pr_comment,
  ]

  spawn_contracts_implement_module = [
    {
      sub_agent_name = "implement-module-discovery-scaffold"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "load_skill",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.hcl_author_max_llm_calls
      max_tool_iterations = 48
      timeout_seconds     = local.subagent_budgets.hcl_author_timeout_seconds
      goal                = "WORK_ROOT={{work_root}}. load_skill ${local.sop_workflow_script_pack} AND ${local.sop_discovery_modules_layout}. ONE bash -lc execute_series: script-pack §2.5 discovery-check with repo_clone_path=$WORK_ROOT/repo, then write ALL discovery layout files in the SAME series (provider/<module_dir>/ only — one path). FORBIDDEN: implement-module-clone, implement-module-scaffold, second subagent, tests/ subdir, main.tf as primary file, repo_clone ad hoc path. note module_paths (single absolute path), scaffold_summary. Stop — defer validate to validate-and-test."
      context             = local.terraform_spawn_context
    },
    {
      sub_agent_name = "implement-module-registry-wrap"
      task_type      = "coding"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "${local.ubuntu_tool_prefix}_execute_parallel",
        "load_skill",
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
        "load_skill",
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
        "load_skill",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.validate_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.validate_runner_timeout_seconds
      goal                = "load_skill ${local.sop_workflow_script_pack}. ONE ${local.ubuntu_tool_prefix}_execute_series only: copy script-pack §2.2 validate block verbatim (bash -lc + _embed_tfbot_run validate for-loop over module_paths). WORK_ROOT={{work_root}}. FORBIDDEN: printf/echo fake PASS, quality_check_terraform, quality_check_module_layout, skipping tofu fmt/init/validate/test, execute_command file probes, second series. Real stdout MUST include fmt_exit= and binary= lines. note workflow_notes_snapshot from tool output only — never invent sentinels."
      context             = local.terraform_spawn_context
    },
  ]

  spawn_contracts_create_pr = [
    {
      sub_agent_name = "create-pr-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "${local.github_tool_prefix}_execute_command",
        "${local.github_tool_prefix}_execute_series",
        "load_skill",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.create_pr_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds + local.subagent_budgets.github_comment_timeout_seconds
      goal                = "load_skill ${local.sop_workflow_script_pack}. (1) ONE ${local.ubuntu_tool_prefix}_execute_series: script-pack §2.3 commit-pr, WORK_ROOT={{work_root}} — note working_branch, pr_url, pr_title. (2) ONE ${local.github_tool_prefix}_execute_series: post outcome comment on PR or issue. Batch workflow_notes_snapshot. Stop — no extra probes."
      context             = local.terraform_spawn_context
    },
    {
      sub_agent_name = "create-pr-register"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.ubuntu_tool_prefix}_execute_command",
        "${local.ubuntu_tool_prefix}_execute_series",
        "load_skill",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.script_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds
      goal                = "Optional StackGen registration when STACKGEN_TOKEN is set. WORK_ROOT={{work_root}}. Skip with note registration_skipped=missing_stackgen_token when unset."
      context             = local.terraform_spawn_context
    },
    local.spawn_contract_create_pr_comment,
  ]
}
