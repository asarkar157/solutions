# Spawn contracts for linear-product-spec and linear-spec-implement workflows.

locals {
  linear_spawn_tool_names = [
    local.linear_tool_save_comment,
    local.linear_tool_list_comments,
  ]

  linear_materialize_context = <<-EOT
${local.specsym_spawn_context_header}
Materialize command (ONE execute_series):
  WORK_ROOT='{{work_root}}' SPECSYM_ALLOW_DIRECT=1 FEATURE_ID='<linear_issue_id>' SPEC_MARKDOWN='<from notes or write to $WORK_ROOT/spec.md>' ENGINEERING_SUBGOALS='<from notes>' LINEAR_IMPLEMENT_ENGINE=${var.linear_implement_engine}; ${local.specsym_pack_ensure_shell_body} && ${local.specsym_pack_dir}/stage-runner.sh linear-materialize '{{work_root}}' '{{work_root}}/repo' '<linear_issue_id>'
Stdout MUST include spec_tasks_path= and stage_summary:materialize-spec=done.
EOT

  spawn_contracts_linear_product_intake = [
    {
      sub_agent_name      = "linear-product-intake"
      task_type           = "efficiency"
      tool_names          = concat(["note", "read_notes"], local.linear_spawn_tool_names)
      max_llm_calls       = 8
      max_tool_iterations = 24
      timeout_seconds     = 120
      goal                = "Parse Linear webhook from stage Input. note linear_issue_id linear_issue_title linear_issue_body linear_labels needs_spec_present (true when label ${var.linear_product_spec_label} present). note stage_summary:linear-intake=done. FORBIDDEN: clone; runner execute_series."
      context             = local.specsym_spawn_context_header
    },
  ]

  spawn_contracts_author_product_spec = [
    {
      sub_agent_name      = "author-product-spec-writer"
      task_type           = "coding"
      tool_names          = ["note", "read_notes"]
      max_llm_calls       = 16
      max_tool_iterations = 32
      timeout_seconds     = 600
      goal                = "Author product spec from golden template in runbook ${local.sop_linear_product_spec_name}. read_notes linear_issue_*. note spec_markdown= with <!-- spec-symphony-spec-v1 --> marker. FORBIDDEN: engineering subgoals; shell runner."
      context             = "Golden template SOP: ${local.sop_linear_product_spec_name}"
    },
  ]

  spawn_contracts_decompose_subgoals = [
    {
      sub_agent_name      = "decompose-subgoals-writer"
      task_type           = "efficiency"
      tool_names          = ["note", "read_notes"]
      max_llm_calls       = 10
      max_tool_iterations = 28
      timeout_seconds     = 300
      goal                = "read_notes spec_markdown. Emit 3-8 numbered engineering subgoals. note engineering_subgoals= and spec_markdown_final= (full spec including ## Engineering subgoals). FORBIDDEN: Linear MCP; implement."
      context             = local.specsym_spawn_context_header
    },
  ]

  spawn_contracts_post_linear_spec_comment = [
    {
      sub_agent_name      = "post-linear-spec-comment"
      task_type           = "efficiency"
      tool_names          = concat(["note", "read_notes"], local.linear_spawn_tool_names)
      max_llm_calls       = 8
      max_tool_iterations = 24
      timeout_seconds     = 180
      goal                = "read_notes linear_issue_id spec_markdown_final. Post ## Spec (draft) comment via ${local.linear_tool_save_comment} only. note linear_comment_posted=true. FORBIDDEN: gh api; runner shell."
      context             = local.specsym_spawn_context_header
    },
  ]

  spawn_contracts_linear_product_finish = [
    {
      sub_agent_name      = "linear-product-spec-finish"
      task_type           = "efficiency"
      tool_names          = ["note", "read_notes"]
      max_llm_calls       = 4
      max_tool_iterations = 12
      timeout_seconds     = 60
      goal                = "note stage_summary:linear-product-spec=done or skipped=needs_spec_label_missing from read_notes."
      context             = local.specsym_spawn_context_header
    },
  ]

  spawn_contracts_linear_implement_intake = [
    {
      sub_agent_name      = "linear-implement-intake"
      task_type           = "efficiency"
      tool_names          = concat(["note", "read_notes"], local.linear_spawn_tool_names)
      max_llm_calls       = 10
      max_tool_iterations = 28
      timeout_seconds     = 180
      goal                = "Parse Linear webhook. note linear_issue_id linear_issue_title linear_labels spec_blessed_present=true when label ${var.linear_implement_label} present else false. Parse repo: owner/name or repository_url from body → repository_full_name repository_clone_url issue_or_pr_number=linear_issue_id. note stage_summary:linear-intake=done."
      context             = local.specsym_spawn_context_header
    },
  ]

  spawn_contracts_fetch_spec_context = [
    {
      sub_agent_name      = "fetch-spec-context-reader"
      task_type           = "efficiency"
      tool_names          = concat(["note", "read_notes"], local.linear_spawn_tool_names)
      max_llm_calls       = 10
      max_tool_iterations = 32
      timeout_seconds     = 300
      goal                = "read_notes linear_issue_id. ${local.linear_tool_list_comments} to find <!-- spec-symphony-spec-v1 -->. note spec_markdown engineering_subgoals spec_comment_found=true. On miss: fetch_spec_blocker=missing_spec_comment."
      context             = local.specsym_spawn_context_header
    },
  ]

  spawn_contracts_materialize_spec = [
    {
      sub_agent_name = "materialize-spec-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = 8
      max_tool_iterations = 42
      timeout_seconds     = 300
      goal                = "FIRST tool: ONE execute_series with spawn-context Materialize command. read_notes spec_tasks_path from stdout."
      context             = local.linear_materialize_context
    },
  ]

  spawn_contracts_post_linear_implement_comment = [
    {
      sub_agent_name      = "post-linear-implement-comment"
      task_type           = "efficiency"
      tool_names          = concat(["note", "read_notes"], local.linear_spawn_tool_names)
      max_llm_calls       = 8
      max_tool_iterations = 24
      timeout_seconds     = 180
      goal                = "read_notes linear_issue_id pr_url ci_status engineering_subgoals. Post summary via ${local.linear_tool_save_comment}. note linear_implement_comment_posted=true."
      context             = local.specsym_spawn_context_header
    },
  ]

  spawn_contracts_linear_implement_finish = [
    {
      sub_agent_name      = "linear-implement-finish"
      task_type           = "efficiency"
      tool_names          = ["note", "read_notes"]
      max_llm_calls       = 4
      max_tool_iterations = 12
      timeout_seconds     = 60
      goal                = "note stage_summary:linear-spec-implement=done or skipped=blessed_label_missing."
      context             = local.specsym_spawn_context_header
    },
  ]

  linear_implement_spawn_contracts = concat(
    var.linear_implement_engine != "cursor_cli" ? local.spawn_contracts_implement : [],
    var.linear_implement_engine == "cursor_cli" ? local.spawn_contracts_implement_cursor : [],
  )
}
