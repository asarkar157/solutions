# Per-stage create_agent contracts (Guild StageBinding.spawn_contracts).
# Bootstrap B64 is set on the Ubuntu integration at tofu apply; spawn context carries a short
# *_EXECUTE_SERIES_DECODE_COMMAND (~300 chars). Runners paste ONE execute_series verbatim.

locals {
  ubuntu_execute_series_shell_dollar_rule = <<-EOT
Ubuntu execute_series shell: use single $ for variables ($WORK_ROOT, $WORKFLOW_RUN_ID). NEVER $$ before a name — bash expands $$ to the shell PID (e.g. $$WORK_ROOT → 79WORK_ROOT). Copy spawn-context *_EXECUTE_SERIES_DECODE_COMMAND lines verbatim; do not re-escape; do not "fix" or rewrite the bootstrap in memory.
EOT

  ubuntu_shared_integration_rule = <<-EOT
SHARED_UBUNTU: The ${local.resolved_ubuntu_integration_name} sidecar is shared by many concurrent workflow runs. Agents have shell only — no power to delete pods, recycle sidecars, or tofu apply. Never tell the operator to do those steps. Per-run isolation: WORK_ROOT=/home/integration/.{{workflow_run_id}}/ (repo, scripts, notes, scans). Decode commands export WORK_ROOT and WORKFLOW_RUN_ID before bootstrap — paste *_EXECUTE_SERIES_DECODE_COMMAND verbatim. Never use /home/integration/.monosplit-work or other shared scratch.
EOT

  monorepo_spawn_context_base = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: /home/integration/.{{workflow_run_id}}
ubuntu_integration_home: ${local.ubuntu_integration_home}
script_pack_version: ${local.script_pack_version}
stage_runner_script_sha256: ${local.script_pack_runner_sha256}
boundary_scan_script_sha256: ${local.script_pack_boundary_scan_sha256}
${local.ubuntu_shared_integration_rule}
MONOSPLIT_PACK: Bootstrap B64 + script pack tarball are in sidecar env (set at tofu apply). Spawn context has a short *_EXECUTE_SERIES_DECODE_COMMAND only — paste verbatim; never inline B64 in tool JSON. Runners MUST NOT create_files embed scripts. No runtime clone of any tooling repo — only the user's github_repo_url is cloned for analysis.
${local.ubuntu_execute_series_shell_dollar_rule}
HALGUARD: halguard_skip_subagent_task_types=terminal_calling (Guild WorkflowMetadata) skips PreCheck on task_type=terminal_calling (short decode goals). Runners: copy decode command verbatim, never load_skill script pack on embed stages. PostCheck still runs on runner stdout.
EMBED_SIZE: decode command is ~300 chars; bootstrap + script pack tarball are sidecar env (tofu apply). After read_notes, prepend exports on the same line: export GITHUB_REPO_URL='<url>' DEFAULT_BRANCH='<branch>' then paste decode command.
EOT

  monorepo_spawn_context_scan = <<-EOT
${local.monorepo_spawn_context_base}

SCAN_RUNNER_RULE: notes_index then read_notes for github_repo_url and default_branch. Tool order: ONE execute_series (working_dir=/, timeout_seconds=${local.subagent_budgets.boundary_scan_timeout_seconds}): prepend export GITHUB_REPO_URL='<from read_notes>' DEFAULT_BRANCH='<from read_notes or main>' then paste SCAN_EXECUTE_SERIES_DECODE_COMMAND exactly (same shell line). Bootstrap prefers MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2 (falls back to V1) plus MONOSPLIT_SCRIPT_PACK_TARBALL_B64 from sidecar env — never git-clone tooling repos. On script_pack_error=runner_sha256_mismatch: note blocked:runner_failed and stage_summary:clone-and-boundary-scan=blocked; include INFRA_HANDOFF table (workflow_run_id, script_pack_version=${local.script_pack_version}, expected stage_runner_script_sha256=${local.script_pack_runner_sha256}, actual from stderr). Tell user to contact platform/infra team for Ubuntu sidecar reprovisioning — do NOT instruct recycle sidecars or manual tofu apply. After sidecar is fixed, user starts a NEW workflow run (new workflow_run_id). On 71WORK_ROOT/79WORK_ROOT: clone_blocker=wrong_shell_dollar_escape. On monosplit_pack_error=missing_b64_env or missing_script_pack_tarball_b64: sidecar env missing or stale. On blocked:missing_github_repo_url: prepend exports from read_notes. Success stdout: boundary_scan_json_attached or stage_summary:clone-and-boundary-scan=ok. Forbidden: execute_command, create_files, second execute_series. After success: note() boundary_scan_json_path, boundary_scan_json_attached, test_inventory_attached, runtime_deps_provisioned, baseline_test_status, script_pack_version=${local.script_pack_version}.

SCAN_EXECUTE_SERIES_DECODE_COMMAND:
${local.monosplit_scan_execute_series_decode_command}
EOT

  monorepo_spawn_context_guidance_pr = <<-EOT
${local.monorepo_spawn_context_base}

GUIDANCE_PR_RUNNER_RULE: notes_index then read_notes if repo_clone_path or default_branch missing. Tool order: ONE execute_series: GUIDANCE_PR_EXECUTE_SERIES_DECODE_COMMAND exactly. NEVER create_files embed scripts or heredocs. Forbidden tools: execute_command, create_files, submit_evidence, search_skill, load_skill. After series: note() guidance_pr_url from notes.json.

GUIDANCE_PR_EXECUTE_SERIES_DECODE_COMMAND:
${local.monosplit_guidance_pr_execute_series_decode_command}
EOT

  monorepo_spawn_context_scaffold = <<-EOT
${local.monorepo_spawn_context_base}

SCAFFOLD_RUNNER_RULE: notes_index then read_notes if plan_artifact_path, github_repo_url, or repo_clone_path missing. Tool order: ONE execute_series: SCAFFOLD_EXECUTE_SERIES_DECODE_COMMAND exactly. NEVER create_files embed scripts or heredocs. Forbidden tools: execute_command, create_files, submit_evidence, search_skill, load_skill, gh pr create. Do NOT open extract PR — scaffold only. After series: note() scaffold_layout_created scaffold_layout_validated scaffold_service_count from runner stdout.

SCAFFOLD_EXECUTE_SERIES_DECODE_COMMAND:
${local.monosplit_scaffold_execute_series_decode_command}
EOT

  monorepo_spawn_context_extract_pr = <<-EOT
${local.monorepo_spawn_context_base}

EXTRACT_PR_RUNNER_RULE: notes_index then read_notes if repo_clone_path or default_branch missing. Require scaffold_layout_validated=true before running. Tool order: ONE execute_series: EXTRACT_PR_EXECUTE_SERIES_DECODE_COMMAND exactly. NEVER create_files embed scripts or heredocs. Forbidden tools: execute_command, create_files, submit_evidence, search_skill, load_skill. PR body is generated from committed diff — do not invent file lists. After series: note() extract_pr_url. PR-only — never push default branch.

EXTRACT_PR_EXECUTE_SERIES_DECODE_COMMAND:
${local.monosplit_extract_pr_execute_series_decode_command}
EOT

  spawn_contracts_clone_and_scan = [
    {
      sub_agent_name = "clone-and-boundary-scan-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "notes_index",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.boundary_scan_max_llm_calls
      max_tool_iterations = local.subagent_budgets.boundary_scan_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.boundary_scan_timeout_seconds
      goal                = "notes_index then read_notes for github_repo_url. ONE execute_series: prepend export GITHUB_REPO_URL and DEFAULT_BRANCH from read_notes, then paste SCAN_EXECUTE_SERIES_DECODE_COMMAND exactly (timeout_seconds=${local.subagent_budgets.boundary_scan_timeout_seconds}). See SCAN_RUNNER_RULE. Forbidden: execute_command, create_files, second execute_series."
      context             = local.monorepo_spawn_context_scan
    },
  ]

  spawn_contracts_guidance_pr = [
    {
      sub_agent_name = "guidance-pr-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "notes_index",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.guidance_pr_max_llm_calls
      max_tool_iterations = local.subagent_budgets.guidance_pr_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.guidance_pr_timeout_seconds
      goal                = "notes_index then read_notes if needed. ONE execute_series: paste GUIDANCE_PR_EXECUTE_SERIES_DECODE_COMMAND exactly. See GUIDANCE_PR_RUNNER_RULE. After series: note() guidance_pr_url. Forbidden: execute_command, create_files, submit_evidence, search_skill, load_skill, inline scripts."
      context             = local.monorepo_spawn_context_guidance_pr
    },
  ]

  spawn_contracts_scaffold_services = [
    {
      sub_agent_name = "scaffold-services-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "notes_index",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.scaffold_services_max_llm_calls
      max_tool_iterations = local.subagent_budgets.scaffold_services_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.scaffold_services_timeout_seconds
      goal                = "notes_index then read_notes if needed. ONE execute_series: paste SCAFFOLD_EXECUTE_SERIES_DECODE_COMMAND exactly. See SCAFFOLD_RUNNER_RULE. After series: note() scaffold_layout_created scaffold_service_count. Forbidden: execute_command, create_files, submit_evidence, search_skill, load_skill."
      context             = local.monorepo_spawn_context_scaffold
    },
  ]

  spawn_contracts_extract_pr = [
    {
      sub_agent_name = "extract-pr-runner"
      task_type      = "terminal_calling"
      tool_names = [
        "${local.resolved_ubuntu_integration_name}_execute_series",
        "note",
        "notes_index",
        "read_notes",
      ]
      max_llm_calls       = local.subagent_budgets.extract_pr_max_llm_calls
      max_tool_iterations = local.subagent_budgets.extract_pr_max_tool_iterations
      timeout_seconds     = local.subagent_budgets.extract_pr_timeout_seconds
      goal                = "notes_index then read_notes if needed. ONE execute_series: paste EXTRACT_PR_EXECUTE_SERIES_DECODE_COMMAND exactly. See EXTRACT_PR_RUNNER_RULE. After series: note() extract_pr_url. Forbidden: execute_command, create_files, submit_evidence, search_skill, load_skill."
      context             = local.monorepo_spawn_context_extract_pr
    },
  ]
}
