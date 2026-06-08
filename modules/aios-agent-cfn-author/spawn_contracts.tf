# Spawn contracts for cfn-author script runners and drift batch workers.

locals {
  shell_tool_prefix = (
    var.create_remote_runner
    && var.remote_runner_attach_to_agent
    && length(module.remote_runner) > 0
  ) ? module.remote_runner[0].runner_name : local.resolved_ubuntu_integration_name

  github_tool_prefix = local.resolved_github_integration_name
  aws_tool_prefix    = local.resolved_aws_integration_name

  runner_spawn_context = <<-EOT
${local.cfn_author_spawn_context_header}
Validate command (ONE execute_series — copy verbatim; working_dir=${local.ubuntu_integration_home}):
  ${local.cfn_author_validate_command}
Quality check command (ONE execute_series — cfn-lint then parallel Checkov/cfn-nag):
  ${local.cfn_author_quality_check_command}
Security guardrails command (ONE execute_series):
  ${local.cfn_author_guardrails_command}
Commit PR command (ONE execute_series):
  ${local.cfn_author_commit_pr_command}
Parse requirements command (ONE execute_series — after writing WORK_ROOT/stage_input.raw):
  ${local.cfn_author_parse_requirements_command}
Parse intent once (ONE execute_series — pipe parent JSON/prose on stdin; preferred):
  ${local.cfn_author_parse_intent_once_command}
Render final summary command (ONE execute_series — write upstream signals to WORK_ROOT/final_stage_input.txt first when needed):
  ${local.cfn_author_render_summary_command}
Architecture lint command (ONE execute_series — post-synthesis NFR + template checks):
  ${local.cfn_author_architecture_lint_command}
Compliance check command (ONE execute_series — FedRAMP + baseline rules):
  ${local.cfn_author_compliance_check_command}
Catalog discover command (ONE execute_series — keyword match catalog templates):
  ${local.cfn_author_catalog_discover_command}
Change-set preview command (ONE execute_series — AWS CLI create/describe/delete change set):
  ${local.cfn_author_change_set_preview_command}
On script_pack_error=: note pr_blocker=missing_script_pack (recycle Ubuntu sidecar after tofu apply when script_pack_version changes).
EOT

  runner_terminal_tools = compact([
    "${local.shell_tool_prefix}_execute_command",
    "${local.shell_tool_prefix}_execute_series",
    "note",
  ])

  runner_shell_tools = concat(local.runner_terminal_tools, ["read_notes"])

  spawn_contract_quality_check = {
    sub_agent_name      = "quality-check-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_terminal_tools
    max_llm_calls       = 3
    max_tool_iterations = 15
    timeout_seconds     = 900
    goal                = "ABS_WORK_ROOT={{work_root}}. Ensure WORK_ROOT/generated/template.yaml exists. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Quality check command verbatim. Mirror stdout keys cfn_lint_passed= validate_template_passed= validate_blocked= security_guardrails_passed= security_guardrails_report_path= security_guardrails_critical_count=. After runner, if cfn_lint_passed=true call AWS validate-template once. Max 1 re-spawn on script_pack_error. FORBIDDEN: load_skill, read_notes, second execute_series, separate guardrails runner."
    context             = local.runner_spawn_context
  }

  spawn_contract_validate_template = {
    sub_agent_name      = "validate-template-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_terminal_tools
    max_llm_calls       = 10
    max_tool_iterations = 25
    timeout_seconds     = 600
    goal                = "ABS_WORK_ROOT={{work_root}}. Ensure WORK_ROOT/generated/template.yaml exists from upstream generate-template. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Validate command verbatim. Mirror stdout keys cfn_lint_passed= validate_template_passed= validate_blocked=. Max 1 re-spawn on script_pack_error. FORBIDDEN: load_skill, second execute_series."
    context             = local.runner_spawn_context
  }

  spawn_contract_security_guardrails = {
    sub_agent_name      = "security-guardrails-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_terminal_tools
    max_llm_calls       = 8
    max_tool_iterations = 20
    timeout_seconds     = 600
    goal                = "ABS_WORK_ROOT={{work_root}}. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Security guardrails command verbatim. Mirror stdout keys security_guardrails_passed= security_guardrails_report_path= security_guardrails_critical_count= checkov_status= cfn_nag_status= policy_scan_passed=. Max 1 re-spawn on script_pack_error. FORBIDDEN: load_skill."
    context             = local.runner_spawn_context
  }

  spawn_contract_parse_requirements = {
    sub_agent_name      = "parse-requirements-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_terminal_tools
    max_llm_calls       = 2
    max_tool_iterations = 8
    timeout_seconds     = 300
    goal                = "ABS_WORK_ROOT={{work_root}}. Parent stage input is JSON or prose in your task — ONE ${local.shell_tool_prefix}_execute_series only: prefer Parse intent once command (pipe parent input on stdin to parse-intent-once). Alternate: single bash -lc writes WORK_ROOT/stage_input.raw then runs Parse requirements command. Mirror stdout keys requirements_parsed= requirements_blocked= correlation_id= orchestration_source= confirm_deploy= only. Parent stage output MUST be ≤6 lines (structured key=value). Max 1 spawn total — on success do NOT re-spawn. FORBIDDEN: load_skill, read_notes, note prose, second execute_series call, catalog discovery LLM."
    context             = local.runner_spawn_context
  }

  spawn_contract_final_intent_summary = {
    sub_agent_name      = "final-intent-summary-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_terminal_tools
    max_llm_calls       = 6
    max_tool_iterations = 15
    timeout_seconds     = 300
    goal                = "ABS_WORK_ROOT={{work_root}}. When parent input contains blocker tokens, ONE execute_series writes last 4KB to WORK_ROOT/final_stage_input.txt. ONE execute_series: Render final summary command verbatim. Mirror markdown stdout as parent stage output (≤45 lines). FORBIDDEN: load_skill, read_notes, LLM prose summary."
    context             = local.runner_spawn_context
  }

  spawn_contract_architecture_fit = {
    sub_agent_name      = "architecture-fit-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_terminal_tools
    max_llm_calls       = 6
    max_tool_iterations = 15
    timeout_seconds     = 300
    goal                = "ABS_WORK_ROOT={{work_root}}. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Architecture lint command verbatim. Mirror stdout keys architecture_lint_passed= architecture_summary= architecture_critical_count= architecture_warning_count= architecture_findings_path= architecture_needs_review= architecture_blocked=. Parent stage output ≤10 lines. FORBIDDEN: load_skill, read_notes, re-litigate findings in prose."
    context             = local.runner_spawn_context
  }

  spawn_contract_open_pr = {
    sub_agent_name      = "open-pr-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_terminal_tools
    max_llm_calls       = 3
    max_tool_iterations = 12
    timeout_seconds     = 600
    goal                = "ABS_WORK_ROOT={{work_root}}. Read WORK_ROOT/requirements_spec.json for PR_TITLE TEMPLATE_FILE STACK_NAME ENVIRONMENT INTENT github_repo_override (FORBIDDEN: read_notes). Build export prefix (REPO_FULL_NAME PR_TITLE TEMPLATE_FILE STACK_NAME ENVIRONMENT INTENT) only — script renders pull request body and runs governed-deployment-check. ONE ${local.shell_tool_prefix}_execute_series only — gh/git on Ubuntu sidecar (FORBIDDEN: github-integration MCP). Mirror pr_url= pr_blocker= clone_blocker= template_path= from stdout. Parent output ≤5 lines. On failure: stage_summary:open-pr=blocked pr_blocker=<reason>. FORBIDDEN: load_skill."
    context             = local.runner_spawn_context
  }

  spawn_contract_compliance_check = {
    sub_agent_name      = "compliance-check-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_terminal_tools
    max_llm_calls       = 2
    max_tool_iterations = 12
    timeout_seconds     = 300
    goal                = "ABS_WORK_ROOT={{work_root}}. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Compliance check command verbatim. Mirror stdout keys compliance_summary= compliance_blocked= only. Parent stage output ≤8 lines. FORBIDDEN: load_skill, read_notes, FedRAMP prose."
    context             = local.runner_spawn_context
  }

  preview_shell_tools = compact([
    "${local.shell_tool_prefix}_execute_command",
    "${local.shell_tool_prefix}_execute_series",
    "note",
  ])

  spawn_contract_preview_changes = {
    sub_agent_name      = "preview-changes-runner"
    task_type           = "terminal_calling"
    tool_names          = local.preview_shell_tools
    max_llm_calls       = 2
    max_tool_iterations = 12
    timeout_seconds     = 900
    goal                = "ABS_WORK_ROOT={{work_root}}. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Change-set preview command verbatim. Read stack_name from WORK_ROOT/requirements_spec.json. Mirror change_set_preview_documented= from stdout. FORBIDDEN: open-pr-runner, github-integration, AWS MCP, load_skill, read_notes."
    context             = local.runner_spawn_context
  }

  spawn_contract_open_reconcile_pr = {
    sub_agent_name      = "open-reconcile-pr-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_shell_tools
    max_llm_calls       = 12
    max_tool_iterations = 30
    timeout_seconds     = 600
    goal                = "ABS_WORK_ROOT={{work_root}}. read_notes reconcile_template_diff incorporate_stack_ids drift_report_json pr_title pr_body. ONE ${local.shell_tool_prefix}_execute_series: stage-runner.sh reconcile-pr (Ubuntu gh only — no github-integration MCP). Mirror reconcile_pr_url= pr_blocker= from stdout. FORBIDDEN: load_skill."
    context             = local.runner_spawn_context
  }

  drift_batch_runner_names = [
    for i in range(1, 5) : format("drift-detect-runner-batch-%02d", i)
  ]

  spawn_contract_drift_batch = {
    for name in local.drift_batch_runner_names : name => {
      sub_agent_name = name
      task_type      = "terminal_calling"
      tool_names = concat(local.runner_shell_tools, compact([
        "${local.aws_tool_prefix}_execute_command",
        "${local.aws_tool_prefix}_execute_series",
      ]))
      max_llm_calls       = 10
      max_tool_iterations = 35
      timeout_seconds     = 900
      goal                = "Batch drift detection for assigned stack_ids slice from batch_payloads.json. ONE ${local.aws_tool_prefix}_execute_series or execute_command per stack: detect-stack-drift, poll status, describe-stack-resource-drifts. On Throttling note drift_retry_stack_ids. Emit drift_findings partial JSON. Read-only — no remediation. Max 1 re-spawn on throttle."
      context             = local.runner_spawn_context
    }
  }

  spawn_contracts_intent_architecture_fit    = [local.spawn_contract_architecture_fit]
  spawn_contracts_intent_parse_requirements  = [local.spawn_contract_parse_requirements]
  spawn_contracts_intent_compliance_check    = [local.spawn_contract_compliance_check]
  spawn_contracts_intent_validate            = [local.spawn_contract_validate_template]
  spawn_contracts_intent_quality_check       = [local.spawn_contract_quality_check]
  spawn_contracts_intent_security_guardrails = [local.spawn_contract_security_guardrails]
  spawn_contracts_intent_open_pr             = [local.spawn_contract_open_pr]
  spawn_contracts_intent_final_summary       = [local.spawn_contract_final_intent_summary]
  spawn_contracts_intent_preview_changes     = [local.spawn_contract_preview_changes]
  spawn_contracts_drift_batches              = [for name in local.drift_batch_runner_names : local.spawn_contract_drift_batch[name]]
  spawn_contracts_drift_reconcile            = [local.spawn_contract_open_reconcile_pr]
}
