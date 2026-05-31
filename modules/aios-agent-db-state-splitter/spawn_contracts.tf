# Per-stage create_agent contracts (Guild StageBinding.spawn_contracts).
# Runtime resolves {{workflow_run_id}}, {{work_root}}, and {{stage_note_var:NAME}} from binding notes.

locals {
  dbsplit_spawn_context = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: /home/integration/.{{workflow_run_id}}
ABS_WORK_ROOT: /home/integration/.{{workflow_run_id}}
ubuntu_integration_home: ${local.ubuntu_integration_home}
DBSPLIT_ALLOCATE_SHA256: ${local.script_pack_allocate_sha256}
script_pack_version: ${local.script_pack_version}

---BEGIN INGEST_EXECUTE_SERIES---
${local.ingest_execute_series_body}
---END INGEST_EXECUTE_SERIES---
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
      goal                = "read_notes monolith_state_uri. ONE ${local.resolved_ubuntu_integration_name}_execute_series: working_dir=/ ONLY (never WORK_ROOT — trace 5740880b/437e7c10 chdir fail). commands.length=1. commands[0].command = export MONOLITH_URI='<uri>' && paste EVERY line between ---BEGIN INGEST_EXECUTE_SERIES--- and ---END INGEST_EXECUTE_SERIES--- from spawn context verbatim (starts with /bin/bash <<'DBSPLIT_INGEST_EXECUTE' — base64-embeds canonical scripts; never curl GitHub; never inline allocate_manifest.py). After execute_series: parse stdout for logical_group_count=, logical_group_manifest_path=, group_state_paths=, monolith_resource_count=, aggregate_group_resource_count=, monolith_state_local_path=, count_reconciliation_ok=, script_pack_verify_ok=, script_pack_version= and call note(key,value) for EACH. Final line echoes count_reconciliation_ok and logical_group_count. Forbidden: create_files, second execute_series, inline python, curl raw.githubusercontent.com, _embed_dbsplit_run(){ wrappers."
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
      goal                = "ABS_WORK_ROOT=/home/integration/.{{workflow_run_id}}. Registry mapping + HCL scaffold + import blocks only. Read group_state_paths from notes. HCL .tf only — never *.tf.json. Spawn goal ≤ 1000 chars; one bounded execute_series per group batch when possible."
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
      goal                = "ABS_WORK_ROOT=/home/integration/.{{workflow_run_id}}. Infra preflight: command -v tofu || command -v terraform — if missing note blocked:ubuntu_infra_tofu_missing and return (do NOT orphan all resources). Per group_id: ONE execute_series tofu init + plan -generate-config-out=generated.tf + verify plan + tofu fmt. Append import_failed_* to orphans_bundle only for real plan failures. Never *.tf.json."
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
      goal                = "ABS_WORK_ROOT=/home/integration/.{{workflow_run_id}}. Run plan convergence matrix per group; note plan_no_changes per group. Decompose into multi-shard-plan-runner-batch-* only when shard count requires it."
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
      goal                = "ABS_WORK_ROOT=/home/integration/.{{workflow_run_id}}. Plan convergence for assigned group_id range only. ≤ 270s per Ubuntu call inside one execute_series per group."
      context             = local.dbsplit_spawn_context
    },
  ]
}
