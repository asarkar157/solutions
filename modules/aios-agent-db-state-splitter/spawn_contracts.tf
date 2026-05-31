# Per-stage create_agent contracts (Guild StageBinding.spawn_contracts).
# Runtime resolves {{workflow_run_id}}, {{work_root}}, and {{stage_note_var:NAME}} from binding notes.

locals {
  dbsplit_spawn_context = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
module_prefix: ${local.module_prefix}
EOT

  spawn_contracts_ingest_and_split = [
    {
      sub_agent_name = "ingest-and-split-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_command",
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.script_runner_max_llm_calls
      max_tool_iterations = local.subagent_budgets.script_runner_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds
      goal                = "WORK_ROOT={{work_root}}. read_notes monolith_state_uri. ONE ${local.resolved_ubuntu_integration_name}_execute_series: mkdir -p {{work_root}}/scripts; heredoc allocate_manifest.py; export DBSPLIT_EMBEDDED=1 DBSPLIT_ALLOCATE_SHA256={{stage_note_var:DBSPLIT_ALLOCATE_SHA256}}; bash -s heredoc _embed_dbsplit_run ingest-and-split {{work_root}} <URI> (bash not /bin/sh). Use literal {{work_root}} in every command — never $WORK_ROOT/$HOME in tool strings. Forbidden: create_files, direct stage-runner.sh, inline python splitters, search_skill. note handoff keys. Final line: count_reconciliation_ok + script_pack_verify_ok + script_pack_version."
      context             = local.dbsplit_spawn_context
    },
  ]

  spawn_contracts_registry_codegen = [
    {
      sub_agent_name = "registry-and-import-codegen-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_command",
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.registry_codegen_max_llm_calls
      max_tool_iterations = local.subagent_budgets.registry_codegen_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.registry_codegen_timeout_seconds
      goal                = "WORK_ROOT={{work_root}}. Registry mapping + HCL scaffold + import blocks only. Read group_state_paths from notes. HCL .tf only — never *.tf.json. Spawn goal ≤ 1000 chars; one bounded execute_series per group batch when possible."
      context             = local.dbsplit_spawn_context
    },
  ]

  spawn_contracts_hcl_hydrate_batch = [
    {
      sub_agent_name = "hcl-hydrate-runner-batch"
      task_type      = "coding"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_command",
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.hcl_hydrate_batch_max_llm_calls
      max_tool_iterations = local.subagent_budgets.hcl_hydrate_batch_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.hcl_hydrate_batch_timeout_seconds
      goal                = "WORK_ROOT={{work_root}}. Infra preflight: command -v tofu || command -v terraform — if missing note blocked:ubuntu_infra_tofu_missing and return (do NOT orphan all resources). Per group_id: ONE execute_series tofu init + plan -generate-config-out=generated.tf + verify plan + tofu fmt. Append import_failed_* to orphans_bundle only for real plan failures. Never *.tf.json."
      context             = local.dbsplit_spawn_context
    },
  ]

  spawn_contracts_appstack_batch = [
    {
      sub_agent_name = "appstack-materialize-runner-batch"
      task_type      = "terminal_calling"
      tool_names = [
        "${trimspace(var.stackgen_mcp_integration_name)}_create_appstack",
        "${trimspace(var.stackgen_mcp_integration_name)}_get_appstacks",
        "${trimspace(var.stackgen_mcp_integration_name)}_get_appstack_resources",
        "${trimspace(var.stackgen_mcp_integration_name)}_bulk_add_resources_to_appstack",
        "${trimspace(var.stackgen_mcp_integration_name)}_bulk_connect_resources_in_appstack",
        "${trimspace(var.stackgen_mcp_integration_name)}_add_resource_to_appstack",
        "${trimspace(var.stackgen_mcp_integration_name)}_connect_resources",
        "${trimspace(var.stackgen_mcp_integration_name)}_delete_resource",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.appstack_batch_max_llm_calls
      max_tool_iterations = local.subagent_budgets.appstack_batch_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.appstack_batch_timeout_seconds
      goal                = "Materialize StackGen AppStacks for disjoint group_id range from logical_group_manifest. Use stackgen_project_name from notes. Do not touch hcl_hydration_status keys."
      context             = local.dbsplit_spawn_context
    },
  ]

  spawn_contracts_plan_convergence = [
    {
      sub_agent_name = "multi-shard-plan-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_command",
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.plan_convergence_batch_max_llm_calls
      max_tool_iterations = local.subagent_budgets.plan_convergence_batch_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.plan_convergence_batch_timeout_seconds
      goal                = "WORK_ROOT={{work_root}}. Run plan convergence matrix per group; note plan_no_changes per group. Decompose into multi-shard-plan-runner-batch-* only when shard count requires it."
      context             = local.dbsplit_spawn_context
    },
    {
      sub_agent_name = "multi-shard-plan-runner-batch"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_command",
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.plan_convergence_batch_max_llm_calls
      max_tool_iterations = local.subagent_budgets.plan_convergence_batch_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.plan_convergence_batch_timeout_seconds
      goal                = "WORK_ROOT={{work_root}}. Plan convergence for assigned group_id range only. ≤ 270s per Ubuntu call inside one execute_series per group."
      context             = local.dbsplit_spawn_context
    },
  ]
}
