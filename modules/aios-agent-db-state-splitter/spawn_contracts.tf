# Per-stage create_agent contracts (Guild StageBinding.spawn_contracts).
# Runtime resolves {{workflow_run_id}}, {{work_root}}, and {{stage_note_var:NAME}} from binding notes.

locals {
  dbsplit_spawn_context_base = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: ${local.runner_work_home}/.{{workflow_run_id}}
ABS_WORK_ROOT: ${local.runner_work_home}/.{{workflow_run_id}}
runner_work_home: ${local.runner_work_home}
remote_runner_name: ${local.resolved_remote_runner_name}
shell_tool_prefix: ${local.shell_tool_prefix}
DBSPLIT_ALLOCATE_SHA256: ${local.script_pack_allocate_sha256}
script_pack_version: ${local.script_pack_version}
script_pack_git_ref: ${local.script_pack_git_ref}
EOT

  dbsplit_spawn_context_ingest = <<-EOT
${local.dbsplit_spawn_context_base}
INGEST_RUNNER_RULE: read_notes monolith_state_uri. Shell tools ONLY: ${local.shell_tool_prefix}_execute_command — NEVER ${local.resolved_github_integration_name}_* or ${local.resolved_aws_integration_name}_* (MCP integrations, not the remote runner; trace 019e905a51fc). Tool order after read_notes: (1) ONE execute_command: mkdir -p ${local.runner_work_home}/.{{workflow_run_id}}/.work ${local.runner_work_home}/.{{workflow_run_id}}/scripts && printf '%s' '<uri>' > ${local.runner_work_home}/.{{workflow_run_id}}/.work/spawn_monolith_uri (replace <uri> from read_notes). (2) ONE execute_command (working_dir=/, timeout_seconds=${local.subagent_budgets.script_runner_timeout_seconds}): paste INGEST_BOOTSTRAP_EXECUTE_COMMAND verbatim — decodes DBSPLIT_INGEST_BOOTSTRAP_B64 from runner script-pack secret JSON (${local.module_prefix}-runner-script-pack-env secret `value` JSON); do NOT use create_files; do NOT paste heredoc or LLM-authored base64. Script pack + ingest bootstrap bytes sync at tofu apply (DBSPLIT_SCRIPT_PACK_* and DBSPLIT_INGEST_BOOTSTRAP_* in secret value JSON). Handoff MUST include script_pack_version ${local.script_pack_version}.

INGEST_BOOTSTRAP_SHA256: ${local.ingest_bootstrap_sha256}

INGEST_BOOTSTRAP_EXECUTE_COMMAND:
${local.ingest_bootstrap_execute_command}
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
      task_type      = var.subagent_task_type
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "note",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.script_runner_max_llm_calls
      max_tool_iterations = local.subagent_budgets.script_runner_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.script_runner_timeout_seconds
      goal                = "read_notes monolith_state_uri. Shell: ONLY ${local.shell_tool_prefix}_execute_command — never github/aws MCP tools. (1) execute_command: mkdir + spawn_monolith_uri. (2) ONE execute_command: paste INGEST_BOOTSTRAP_EXECUTE_COMMAND from context verbatim (timeout_seconds=${local.subagent_budgets.script_runner_timeout_seconds}, working_dir=/). Forbidden: create_files, heredoc, LLM-authored base64, custom goals. See INGEST_RUNNER_RULE. After bootstrap: cat .work/ingest-handoff.txt and note() handoff keys. Retry: THIS goal verbatim."
      context             = local.dbsplit_spawn_context_ingest
    },
  ]

  spawn_contracts_registry_codegen = [
    {
      sub_agent_name = "registry-and-import-codegen-runner"
      task_type      = var.subagent_task_type
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
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
      task_type      = var.subagent_task_type
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${local.shell_tool_prefix}_execute_series",
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
      task_type      = var.subagent_task_type
      tool_names = [
        "${local.shell_tool_prefix}_execute_command",
        "${trimspace(var.stackgen_mcp_integration_name)}_me",
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
      goal                = "read_notes batch_payloads_path, large_state_sample_group_ids, stackgen_project_name (if empty call ${trimspace(var.stackgen_mcp_integration_name)}_me once). For each assigned group_id: ONE ${local.shell_tool_prefix}_execute_command on the runner to jq -c the matching entry from batch_payloads.json (path from read_notes; working_dir=/). Use that resources[], appstack_name, cloud_hint verbatim for create_appstack + bulk_add on mothership MCP — do not rebuild payloads from manifest. Materialize per stackgen-appstack-mcp-playbook-sop: atomic create+bulk_add per group, membership gate, then bulk_connect. Forbidden: guessing payloads without reading batch_payloads.json on the runner."
      context             = local.dbsplit_spawn_context
    },
  ]
}
