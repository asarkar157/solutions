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

---BEGIN VALIDATE_EXECUTE_SERIES---
${local.validate_execute_series_body}
---END VALIDATE_EXECUTE_SERIES---

---BEGIN COMMIT_PR_EXECUTE_SERIES---
${local.commit_pr_execute_series_body}
---END COMMIT_PR_EXECUTE_SERIES---

---BEGIN DISCOVERY_SCAFFOLD_EXECUTE_SERIES---
${local.discovery_scaffold_execute_series_body}
---END DISCOVERY_SCAFFOLD_EXECUTE_SERIES---
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
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.hcl_author_max_llm_calls
      max_tool_iterations = 48
      timeout_seconds     = local.subagent_budgets.hcl_author_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. Greenfield discovery ONLY. ONE ${local.ubuntu_tool_prefix}_execute_series commands.length=1 timeout 600: optional export TRIGGER_JSON='…' MODULE_DIR='…' && paste ---BEGIN DISCOVERY_SCAFFOLD_EXECUTE_SERIES--- through ---END--- verbatim (copies sibling aws_ecs_service layout with basic.tftest.hcl). note module_paths, scaffold_summary from stdout. FORBIDDEN: load_skill, _embed_tfbot_run, tests/ subdir, discovery-check.tf junk files, multiple execute_series."
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
      goal                = "ABS_WORK_ROOT={{work_root}}. Resolve MODULE_PATH plus REPO_FULL_NAME, ISSUE_OR_PR, BASE_BRANCH, TRIGGER_JSON from read_notes or architect context. ONE ${local.ubuntu_tool_prefix}_execute_series only: commands.length=1, commands[0].timeout_seconds=600. commands[0].command = export MODULE_PATH='…' REPO_FULL_NAME='…' ISSUE_OR_PR='…' TRIGGER_JSON='…' && paste ---BEGIN VALIDATE_EXECUTE_SERIES--- through ---END--- verbatim. On PASS the embedded script commits, pushes, and opens PR (pr_url=, pr_prepushed=true) — note working_branch, pr_url, pr_title in workflow_notes_snapshot. stdout MUST include fmt_exit= and binary=OpenTofu. FORBIDDEN: printf fake PASS, load_skill."
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
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.create_pr_runner_max_llm_calls
      max_tool_iterations = 45
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds + local.subagent_budgets.github_comment_timeout_seconds
      goal                = "ABS_WORK_ROOT={{work_root}}. read_notes pr_url, working_branch, pr_title, repository_full_name, issue_or_pr_number. If pr_url already set from validate-and-test → skip Ubuntu series; ONE ${local.github_tool_prefix}_execute_series: gh issue comment with PR link only. Else (1) ONE ${local.ubuntu_tool_prefix}_execute_series commands.length=1 timeout 120: export REPO_FULL_NAME=… ISSUE_OR_PR=… WORKING_BRANCH='…' PR_TITLE='…' TRIGGER_JSON=… && paste ---BEGIN COMMIT_PR_EXECUTE_SERIES--- through ---END--- (recovers latest terraform-bot/* branch when WORKING_BRANCH empty). note pr_url from stdout. (2) ONE ${local.github_tool_prefix}_execute_series: gh issue comment. FORBIDDEN: load_skill, re-clone when branch exists on remote. Stop after PR + comment."
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
