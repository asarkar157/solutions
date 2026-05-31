# Per-stage create_agent contracts (Guild StageBinding.spawn_contracts).
# Runtime resolves {{workflow_run_id}}, {{work_root}}, and {{stage_note_var:NAME}} from binding notes.

locals {
  terraform_spawn_context = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
ABS_WORK_ROOT: {{work_root}}
ubuntu_integration_home: ${local.ubuntu_integration_home}
TFBOT_CLONE_PACK_SHA256: ${local.script_pack_clone_sha256}
script_pack_version: ${local.script_pack_version}

---BEGIN CLONE_EXECUTE_SERIES---
${local.clone_execute_series_body}
---END CLONE_EXECUTE_SERIES---
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
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.script_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. Resolve repository_clone_url, repository_default_branch, issue_or_pr_number from (1) read_notes, (2) architect create_agent context key=value lines, (3) export TRIGGER_JSON='<webhook JSON from stage Input>' when read_notes count=0. ONE ${local.ubuntu_tool_prefix}_execute_series only: commands.length=1, commands[0].timeout_seconds=300. commands[0].command = optional export REPO_CLONE_URL=… && export DEFAULT_BRANCH=… && export ISSUE_OR_PR=… && optional export TRIGGER_JSON='…' && then paste EVERY line between ---BEGIN CLONE_EXECUTE_SERIES--- and ---END CLONE_EXECUTE_SERIES--- from spawn context (verbatim). Embedded script parses TRIGGER_JSON when exports missing. FORBIDDEN: load_skill, create_files, second execute_series, _embed_tfbot_run(){ , ad hoc git clone only. note repo_clone_path, repo_head_sha from stdout. Expect script_pack_version=${local.script_pack_version}."
      context             = local.terraform_spawn_context
    },
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
      goal                = "WORK_ROOT={{work_root}}. load_skill ${local.sop_workflow_script_pack} AND ${local.sop_discovery_modules_layout}. ONE ${local.ubuntu_tool_prefix}_execute_series commands.length=1: script-pack §2.5 /bin/bash -s <<'TFBOT_SCAFFOLD_SERIES' with discovery-check + ALL layout file writes in same heredoc. FORBIDDEN: _embed_tfbot_run(){ , multiple commands[], implement-module-clone, tests/ subdir, main.tf as primary. note module_paths (single absolute path), scaffold_summary."
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
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.validate_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.validate_runner_timeout_seconds
      goal                = "WORK_ROOT={{work_root}}. read_notes module_paths. ONE ${local.ubuntu_tool_prefix}_execute_series commands.length=1. Use script-pack §2.2: /bin/bash -s validate {{work_root}} \"<path>\" <<'TFBOT_STAGE_RUNNER' export TFBOT_EMBEDDED=1 + §1b stage-runner body, TFBOT_STAGE_RUNNER (or §2.2 multi-path bash -s <<'TFBOT_VALIDATE_SERIES' loop). FORBIDDEN: _embed_tfbot_run(){ , multiple commands[], printf fake PASS, quality_check_terraform, quality_check_module_layout. stdout MUST include fmt_exit= and binary=. note workflow_notes_snapshot from tool output only."
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
      goal                = "WORK_ROOT={{work_root}}. (1) ONE ${local.ubuntu_tool_prefix}_execute_series commands.length=1: script-pack §2.3 /bin/bash -s commit-pr {{work_root}} … <<'TFBOT_STAGE_RUNNER' — note working_branch, pr_url, pr_title. (2) ONE ${local.github_tool_prefix}_execute_series: post outcome comment. FORBIDDEN: _embed_tfbot_run(){ , multiple Ubuntu commands[]. Stop after PR + comment."
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
  ]
}
