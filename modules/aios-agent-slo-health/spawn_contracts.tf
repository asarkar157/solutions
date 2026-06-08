# Spawn contracts for bootstrap validate/draft batches and open-slo-pr-runner.

locals {
  shell_tool_prefix = (
    var.create_remote_runner
    && var.remote_runner_attach_to_agent
    && length(module.remote_runner) > 0
  ) ? module.remote_runner[0].runner_name : local.resolved_ubuntu_integration_name

  grafana_tool_prefix = local.resolved_grafana_integration_name
  github_tool_prefix  = local.resolved_github_integration_name

  validate_spawn_context = <<-EOT
${local.slo_health_spawn_context_header}
Validate ONLY proposal IDs listed in read_notes key validate_batch_<suffix>_ids (comma-separated or JSON array).
Read slo_proposals from read_notes before tool use.
Emit note validate_batch_<suffix>_result JSON with validated proposals for this batch only.
Read-only Grafana — no Git mutations. Max 6 query_metric calls per batch.
EOT

  validate_grafana_tools = compact([
    "${local.grafana_tool_prefix}_query_metric",
    "${local.grafana_tool_prefix}_execute_command",
    "note",
    "read_notes",
  ])

  runner_shell_tools = compact([
    "${local.shell_tool_prefix}_execute_command",
    "${local.shell_tool_prefix}_execute_series",
    "note",
    "read_notes",
  ])

  spawn_contract_validate_batch_a = {
    sub_agent_name      = "validate-promql-batch-a"
    task_type           = "efficiency"
    tool_names          = local.validate_grafana_tools
    max_llm_calls       = 10
    max_tool_iterations = 24
    timeout_seconds     = 480
    goal                = "read_notes validate_batch_a_ids slo_proposals. Validate ONLY IDs in validate_batch_a_ids via ${local.grafana_tool_prefix}_query_metric (good + total queries). Emit note validate_batch_a_result JSON array. Read-only. FORBIDDEN: create_agent, GitHub write, create_files."
    context             = replace(local.validate_spawn_context, "<suffix>", "a")
  }

  spawn_contract_validate_batch_b = {
    sub_agent_name      = "validate-promql-batch-b"
    task_type           = "efficiency"
    tool_names          = local.validate_grafana_tools
    max_llm_calls       = 10
    max_tool_iterations = 24
    timeout_seconds     = 480
    goal                = "read_notes validate_batch_b_ids slo_proposals. Validate ONLY IDs in validate_batch_b_ids via ${local.grafana_tool_prefix}_query_metric (good + total queries). Emit note validate_batch_b_result JSON array. Read-only. FORBIDDEN: create_agent, GitHub write, create_files."
    context             = replace(local.validate_spawn_context, "<suffix>", "b")
  }

  spawn_contract_validate_batch_c = {
    sub_agent_name      = "validate-promql-batch-c"
    task_type           = "efficiency"
    tool_names          = local.validate_grafana_tools
    max_llm_calls       = 10
    max_tool_iterations = 24
    timeout_seconds     = 480
    goal                = "read_notes validate_batch_c_ids slo_proposals. Validate ONLY IDs in validate_batch_c_ids via ${local.grafana_tool_prefix}_query_metric (good + total queries). Emit note validate_batch_c_result JSON array. Read-only. FORBIDDEN: create_agent, GitHub write, create_files."
    context             = replace(local.validate_spawn_context, "<suffix>", "c")
  }

  spawn_contract_validate_batch_d = {
    sub_agent_name      = "validate-promql-batch-d"
    task_type           = "efficiency"
    tool_names          = local.validate_grafana_tools
    max_llm_calls       = 10
    max_tool_iterations = 24
    timeout_seconds     = 480
    goal                = "read_notes validate_batch_d_ids slo_proposals. Validate ONLY IDs in validate_batch_d_ids via ${local.grafana_tool_prefix}_query_metric (good + total queries). Emit note validate_batch_d_result JSON array. Read-only. FORBIDDEN: create_agent, GitHub write, create_files."
    context             = replace(local.validate_spawn_context, "<suffix>", "d")
  }

  spawn_contracts_validate_all = [
    local.spawn_contract_validate_batch_a,
    local.spawn_contract_validate_batch_b,
    local.spawn_contract_validate_batch_c,
    local.spawn_contract_validate_batch_d,
  ]

  spawn_contracts_validate_parallel = slice(
    local.spawn_contracts_validate_all,
    0,
    min(var.max_parallel_batches, 4),
  )

  draft_spawn_context = <<-EOT
${local.slo_health_spawn_context_header}
Draft OpenSLO YAML command (ONE execute_series — copy verbatim):
  ${local.slo_health_write_drafts_command}
Optional env BATCH_IDS=<comma-separated proposal ids> when batch suffix is set in read_notes draft_batch_<suffix>_ids.
Prerequisite: coordinator wrote WORK_ROOT/slo_proposals_validated.json before spawn.
Mirror stdout keys draft_files_count= draft_blocker= from runner.
FORBIDDEN: create_files with empty payload, github-integration MCP, load_skill.
EOT

  spawn_contract_draft_batch_a = {
    sub_agent_name      = "draft-yaml-batch-a"
    task_type           = "terminal_calling"
    tool_names          = local.runner_shell_tools
    max_llm_calls       = 8
    max_tool_iterations = 20
    timeout_seconds     = 420
    goal                = "ABS_WORK_ROOT={{work_root}}. read_notes draft_batch_a_ids. If draft_batch_a_ids non-empty, prepend export BATCH_IDS=<ids> to Draft command. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Draft OpenSLO YAML command verbatim. Mirror draft_files_count= draft_blocker=. FORBIDDEN: create_files, load_skill."
    context             = replace(local.draft_spawn_context, "<suffix>", "a")
  }

  spawn_contract_draft_batch_b = {
    sub_agent_name      = "draft-yaml-batch-b"
    task_type           = "terminal_calling"
    tool_names          = local.runner_shell_tools
    max_llm_calls       = 8
    max_tool_iterations = 20
    timeout_seconds     = 420
    goal                = "ABS_WORK_ROOT={{work_root}}. read_notes draft_batch_b_ids. If draft_batch_b_ids non-empty, prepend export BATCH_IDS=<ids> to Draft command. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Draft OpenSLO YAML command verbatim. Mirror draft_files_count= draft_blocker=. FORBIDDEN: create_files, load_skill."
    context             = replace(local.draft_spawn_context, "<suffix>", "b")
  }

  spawn_contract_draft_batch_c = {
    sub_agent_name      = "draft-yaml-batch-c"
    task_type           = "terminal_calling"
    tool_names          = local.runner_shell_tools
    max_llm_calls       = 8
    max_tool_iterations = 20
    timeout_seconds     = 420
    goal                = "ABS_WORK_ROOT={{work_root}}. read_notes draft_batch_c_ids. If draft_batch_c_ids non-empty, prepend export BATCH_IDS=<ids> to Draft command. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Draft OpenSLO YAML command verbatim. Mirror draft_files_count= draft_blocker=. FORBIDDEN: create_files, load_skill."
    context             = replace(local.draft_spawn_context, "<suffix>", "c")
  }

  spawn_contract_draft_batch_d = {
    sub_agent_name      = "draft-yaml-batch-d"
    task_type           = "terminal_calling"
    tool_names          = local.runner_shell_tools
    max_llm_calls       = 8
    max_tool_iterations = 20
    timeout_seconds     = 420
    goal                = "ABS_WORK_ROOT={{work_root}}. read_notes draft_batch_d_ids. If draft_batch_d_ids non-empty, prepend export BATCH_IDS=<ids> to Draft command. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Draft OpenSLO YAML command verbatim. Mirror draft_files_count= draft_blocker=. FORBIDDEN: create_files, load_skill."
    context             = replace(local.draft_spawn_context, "<suffix>", "d")
  }

  spawn_contract_draft_single = {
    sub_agent_name      = "draft-openslo-yaml-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_shell_tools
    max_llm_calls       = 10
    max_tool_iterations = 25
    timeout_seconds     = 600
    goal                = "ABS_WORK_ROOT={{work_root}}. Prerequisite: WORK_ROOT/slo_proposals_validated.json exists (coordinator writes before spawn). ONE ${local.shell_tool_prefix}_execute_series with spawn-context Draft OpenSLO YAML command verbatim — no BATCH_IDS. Mirror draft_files_count= draft_manifest= draft_blocker=. FORBIDDEN: create_files, load_skill, ad-hoc sub-agents."
    context             = local.draft_spawn_context
  }

  spawn_contracts_draft_all = [
    local.spawn_contract_draft_batch_a,
    local.spawn_contract_draft_batch_b,
    local.spawn_contract_draft_batch_c,
    local.spawn_contract_draft_batch_d,
  ]

  spawn_contracts_draft_parallel = concat(
    slice(local.spawn_contracts_draft_all, 0, min(var.max_parallel_batches, 4)),
  )

  spawn_contracts_draft = var.enable_parallel_draft_batches ? local.spawn_contracts_draft_parallel : [local.spawn_contract_draft_single]

  runner_spawn_context = <<-EOT
${local.slo_health_spawn_context_header}
Commit OpenSLO PR command (ONE execute_series — copy verbatim):
  ${local.slo_health_commit_pr_command}
Before spawn: ensure draft YAML exists under WORK_ROOT/openslo-drafts/ mirroring openslo/slos/<service>/ layout.
Set PR_TITLE and PR_BODY in notes when provided by upstream preview stage.
On script_pack_error=: note pr_blocker=missing_script_pack (recycle Ubuntu sidecar after tofu apply when script_pack_version changes).
EOT

  spawn_contract_open_slo_pr = {
    sub_agent_name      = "open-slo-pr-runner"
    task_type           = "terminal_calling"
    tool_names          = local.runner_shell_tools
    max_llm_calls       = 12
    max_tool_iterations = 30
    timeout_seconds     = 600
    goal                = "ABS_WORK_ROOT={{work_root}}. read_notes pr_title pr_body branch_prefix. ONE ${local.shell_tool_prefix}_execute_series with spawn-context Commit OpenSLO PR command verbatim — gh/git on Ubuntu sidecar only (FORBIDDEN: github-integration MCP for push). Mirror pr_url= pr_blocker= clone_blocker= files_committed= from stdout. On failure emit stage_summary:open-slo-pr=blocked pr_blocker=<reason>. FORBIDDEN: load_skill when spawn context includes execute_series block."
    context             = local.runner_spawn_context
  }

  spawn_contracts_open_slo_pr = [local.spawn_contract_open_slo_pr]
}
