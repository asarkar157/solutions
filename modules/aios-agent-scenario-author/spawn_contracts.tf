# Per-stage create_agent contracts (Guild StageBinding.spawn_contracts).

locals {
  scenario_spawn_context = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
repository_full_name: ${var.repository_full_name}
scenario_request_label: ${var.scenario_request_label}
EOT

  spawn_contracts_analyze_issue = [
    {
      sub_agent_name = "analyze-issue-fetch-issue"
      task_type      = "efficiency"
      tool_names = [
        "${local.resolved_github_integration_name}_execute_command",
        "${local.resolved_github_integration_name}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 3
      max_tool_iterations = 3
      timeout_seconds     = 60
      goal                = "Fetch issue via gh api for repository_full_name and issue_or_pr_number from notes. note key=issue_details with JSON. FORBIDDEN: gh auth token, clone, org search. Stop after note."
      context             = local.scenario_spawn_context
    },
    {
      sub_agent_name = "analyze-issue-comment-gate-fail"
      task_type      = "efficiency"
      tool_names = [
        "${local.resolved_github_integration_name}_execute_command",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 2
      max_tool_iterations = 2
      timeout_seconds     = 45
      goal                = "Post gate-fail gh issue comment for gate_result wrong_repo or missing_label. Stop after comment."
      context             = local.scenario_spawn_context
    },
  ]

  spawn_contracts_cursor_author = [
    {
      sub_agent_name = "cursor-author-run-task"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_cursor_integration_name}_cursor_agents_run_task",
        "${local.resolved_cursor_integration_name}_cursor_agents_get_conversation",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 6
      max_tool_iterations = 6
      timeout_seconds     = 720
      goal                = "ONE cursor_agents_run_task with inlined cursor-author SOP + issue context from notes. Persist cursor_verdict, cursor_pr_url, cursor_match_name, cursor_summary, cursor_artifacts. fireAndForget=false. On FAILED set cursor_verdict=blocked."
      context             = local.scenario_spawn_context
    },
  ]

  spawn_contracts_notify_issue = [
    {
      sub_agent_name = "notify-issue-comment"
      task_type      = "efficiency"
      tool_names = [
        "${local.resolved_github_integration_name}_execute_command",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 3
      max_tool_iterations = 3
      timeout_seconds     = 60
      goal                = "ONE gh issue comment per scenario-pr-and-notify-sop branch from notes (gate, match, pr, draft_pr, blocked, guild cap). note final_comment_kind."
      context             = local.scenario_spawn_context
    },
  ]
}
