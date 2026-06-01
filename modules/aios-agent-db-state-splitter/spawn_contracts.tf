# Per-stage create_agent contracts (Guild StageBinding.spawn_contracts).
# Runtime resolves {{workflow_run_id}}, {{work_root}}, and {{stage_note_var:NAME}} from binding notes.

locals {
  dbsplit_spawn_context_base = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: /home/integration/.{{workflow_run_id}}
ABS_WORK_ROOT: /home/integration/.{{workflow_run_id}}
ubuntu_integration_home: ${local.ubuntu_integration_home}
DBSPLIT_ALLOCATE_SHA256: ${local.script_pack_allocate_sha256}
script_pack_version: ${local.script_pack_version}
script_pack_git_ref: ${local.script_pack_git_ref}
EOT

  dbsplit_spawn_context_ingest = <<-EOT
${local.dbsplit_spawn_context_base}
INGEST_RUNNER_RULE: read_notes monolith_state_uri. Tool order after read_notes: (1) ONE execute_command: mkdir -p /home/integration/.{{workflow_run_id}}/.work /home/integration/.{{workflow_run_id}}/scripts && printf '%s' '<uri>' > /home/integration/.{{workflow_run_id}}/.work/spawn_monolith_uri. (2) ONE create_files: .../ingest-embed.b64 = INGEST_EXECUTE_SERIES_B64 verbatim (embed git-clones scripts via GIT_TOKEN). (3) ONE execute_series (working_dir=/, timeout_seconds=${local.subagent_budgets.script_runner_timeout_seconds}): INGEST_EXECUTE_SERIES_DECODE_COMMAND exactly. NEVER paste spawn B64 chunks (redacted), heredoc, or printf-wrapped ingest B64. Handoff MUST include script_pack_version ${local.script_pack_version}.

INGEST_EXECUTE_SERIES_B64:
${local.ingest_execute_series_b64}

INGEST_EXECUTE_SERIES_DECODE_COMMAND:
${local.ingest_execute_series_decode_command}
EOT

  dbsplit_spawn_context_registry = <<-EOT
${local.dbsplit_spawn_context_base}

---BEGIN IAC_PR_EXECUTE_SERIES---
${local.iac_pr_execute_series_body}
---END IAC_PR_EXECUTE_SERIES---
EOT

  dbsplit_spawn_context_converge = <<-EOT
${local.dbsplit_spawn_context_base}

---BEGIN CONVERGE_EXECUTE_SERIES---
${local.converge_execute_series_body}
---END CONVERGE_EXECUTE_SERIES---
EOT

  dbsplit_spawn_context = local.dbsplit_spawn_context_base

  spawn_contracts_ingest_and_split = [
    {
      sub_agent_name = "ingest-and-split-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_command",
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "${local.resolved_ubuntu_integration_name}_create_files",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.script_runner_max_llm_calls
      max_tool_iterations = local.subagent_budgets.script_runner_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds
      goal                = "read_notes monolith_state_uri. (1) execute_command: mkdir + spawn_monolith_uri. (2) create_files ingest-embed.b64 from INGEST_EXECUTE_SERIES_B64. (3) execute_series INGEST_EXECUTE_SERIES_DECODE_COMMAND (timeout_seconds=${local.subagent_budgets.script_runner_timeout_seconds}). Embed fetches scripts via git (GIT_TOKEN). See INGEST_RUNNER_RULE. After series: cat ingest-handoff.txt and note() handoff keys. Retry: THIS goal verbatim."
      context             = local.dbsplit_spawn_context_ingest
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
      timeout_seconds     = 1800
      goal                = "read_notes iac_repository_url default_branch count_reconciliation_ok. ONE execute_series: paste IAC_PR_EXECUTE_SERIES verbatim (iac-pr-pipeline includes prepare-parallel-artifacts). After execute_series: note() pr_url, batch_payloads_path, large_state_sample_group_ids, groups_synced_to_repo. Forbidden: inline python, create_files, *-probe."
      context             = local.dbsplit_spawn_context_registry
    },
  ]

  spawn_contracts_shell_converge = [
    {
      sub_agent_name = "shell-converge-matrix-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_command",
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.registry_codegen_max_llm_calls
      max_tool_iterations = local.subagent_budgets.registry_codegen_max_tool_iterations
      timeout_seconds     = 1800
      goal                = "ONE execute_series: paste CONVERGE_EXECUTE_SERIES verbatim (hydrate-and-plan-matrix). After execute_series: note() multi_plan_zero_diff_ok and hydrate_ok_groups from stdout. Mirror hcl_hydration_status keys from notes.json to note(). Forbidden: hcl-hydrate-runner-batch, *-probe."
      context             = local.dbsplit_spawn_context_converge
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
      goal                = "Read batch_payloads.json for assigned group_ids. Materialize AppStacks per stackgen-appstack-mcp-playbook-sop. Use bulk_add + membership gate. Read batch_payloads at $WORK_ROOT/batch_payloads.json — do NOT extract payloads manually."
      context             = local.dbsplit_spawn_context
    },
  ]
}
