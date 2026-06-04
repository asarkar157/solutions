terraform {
  required_version = ">= 1.5"
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

# Tarball path includes stage-runner SHA so a script change cannot leave a stale
# .generated/monosplit-script-pack.tar.gz paired with fresh sha256() in embed templates.
data "archive_file" "monosplit_script_pack" {
  type        = "tar.gz"
  source_dir  = "${path.module}/scripts"
  output_path = "${path.module}/.generated/monosplit-script-pack-${sha256(file("${path.module}/scripts/stage-runner.sh"))}.tar.gz"
}

locals {
  module_prefix = "monorepo-services-splitter"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_architect_name = "monorepo-split-architect${local.suffix}"
  agent_analyst_name   = "split-domain-analyst${local.suffix}"
  agent_cursor_name    = "cursor-split-executor${local.suffix}"

  workflow_analysis_name = "monorepo-services-split-analysis${local.suffix}"
  workflow_extract_name  = "monorepo-services-split-extract${local.suffix}"
  webhook_name           = "github-monorepo-split-receiver${local.suffix}"

  sop_orchestration_name    = "monorepo-split-orchestration-sop${local.suffix}"
  sop_clone_scan_name       = "monorepo-clone-and-scan-sop${local.suffix}"
  sop_bounded_context_name  = "bounded-context-analysis-sop${local.suffix}"
  sop_split_recommend_name  = "microservices-split-recommendation-sop${local.suffix}"
  sop_guidance_pr_name      = "split-guidance-pr-sop${local.suffix}"
  sop_extract_scaffold_name = "split-extract-scaffold-sop${local.suffix}"
  sop_load_plan_name        = "split-load-approved-plan-sop${local.suffix}"
  sop_cursor_extract_name   = "cursor-service-extraction-sop${local.suffix}"

  policy_readonly_name   = "monorepo-split-readonly-default${local.suffix}"
  evidence_analysis_name = "monorepo-split-analysis-evidence${local.suffix}"
  evidence_extract_name  = "monorepo-split-extract-evidence${local.suffix}"

  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  ubuntu_integration_name = "${local.module_prefix}-ubuntu${local.suffix}"

  provision_github = trimspace(var.existing_github_integration_name) == "" && trimspace(try(var.integration_names.github, "")) == ""
  provision_ubuntu = trimspace(var.existing_ubuntu_integration_name) == "" && trimspace(try(var.integration_names.ubuntu_cli, "")) == ""

  resolved_github_integration_name = coalesce(
    trimspace(try(var.integration_names.github, "")) != "" ? trimspace(var.integration_names.github) : null,
    trimspace(var.existing_github_integration_name) != "" ? trimspace(var.existing_github_integration_name) : null,
    local.provision_github ? module.github_integration[0].integration_name : "",
  )
  resolved_ubuntu_integration_name = coalesce(
    trimspace(try(var.integration_names.ubuntu_cli, "")) != "" ? trimspace(var.integration_names.ubuntu_cli) : null,
    trimspace(var.existing_ubuntu_integration_name) != "" ? trimspace(var.existing_ubuntu_integration_name) : null,
    local.provision_ubuntu ? module.ubuntu_integration[0].integration_name : "",
  )

  resolved_cursor_mcp_integration_name = trimspace(var.existing_cursor_mcp_integration_name)

  stage_runner_script               = trimspace(file("${path.module}/scripts/stage-runner.sh"))
  boundary_scan_script              = trimspace(file("${path.module}/scripts/boundary-scan.sh"))
  clone_and_pr_script               = trimspace(file("${path.module}/scripts/clone-and-pr.sh"))
  scaffold_services_script          = trimspace(file("${path.module}/scripts/scaffold-services.sh"))
  agents_md_scaffold_script         = trimspace(file("${path.module}/scripts/agents-md-scaffold.sh"))
  runtime_deps_provision_script     = trimspace(file("${path.module}/scripts/runtime-deps-provision.sh"))
  ubuntu_integration_home           = "/home/integration"
  script_pack_version               = "20260602.14"
  monosplit_script_pack_tarball_b64 = filebase64(data.archive_file.monosplit_script_pack.output_path)
  # Hash on-disk script bytes (must match archive_file tarball entries; trimspace is only for embed templates).
  script_pack_runner_sha256             = sha256(file("${path.module}/scripts/stage-runner.sh"))
  script_pack_boundary_scan_sha256      = sha256(file("${path.module}/scripts/boundary-scan.sh"))
  script_pack_clone_and_pr_sha256       = sha256(file("${path.module}/scripts/clone-and-pr.sh"))
  script_pack_scaffold_services_sha256  = sha256(file("${path.module}/scripts/scaffold-services.sh"))
  script_pack_agents_md_scaffold_sha256 = sha256(file("${path.module}/scripts/agents-md-scaffold.sh"))
  script_pack_runtime_deps_sha256       = sha256(file("${path.module}/scripts/runtime-deps-provision.sh"))

  subagent_budget_defaults = {
    boundary_scan_max_llm_calls           = 12
    boundary_scan_max_tool_iterations     = 40
    boundary_scan_timeout_seconds         = 1800
    guidance_pr_max_llm_calls             = 35
    guidance_pr_max_tool_iterations       = 40
    guidance_pr_timeout_seconds           = 1200
    scaffold_services_max_llm_calls       = 35
    scaffold_services_max_tool_iterations = 40
    scaffold_services_timeout_seconds     = 1200
    extract_pr_max_llm_calls              = 35
    extract_pr_max_tool_iterations        = 40
    extract_pr_timeout_seconds            = 1200
  }
  subagent_budgets = {
    for key, default in local.subagent_budget_defaults :
    key => coalesce(try(var.subagent_budgets[key], null), default)
  }

  # Guild reads halguard_skip_subagent_task_types to skip HalGuard PreCheck on
  # terminal_calling runners (short decode command in spawn context; B64 in sidecar env). terminal_calling_halguard_mode
  # documents paste-only runner discipline for personas/SOPs.
  workflow_execution_metadata = {
    planner_max_tool_iterations       = "12"
    halguard_skip_subagent_task_types = "terminal_calling"
    terminal_calling_halguard_mode    = "paste_only_minimal_planner"
  }

  # Embed shell templates must not reference resolved_* integration names — those depend on
  # module.ubuntu_integration output while decode commands are rendered here (cycle if referenced).
  embed_template_vars_base = {
    default_branch                        = trimspace(var.default_branch)
    script_pack_version                   = local.script_pack_version
    script_pack_runner_sha256             = local.script_pack_runner_sha256
    script_pack_boundary_scan_sha256      = local.script_pack_boundary_scan_sha256
    script_pack_clone_and_pr_sha256       = local.script_pack_clone_and_pr_sha256
    script_pack_scaffold_services_sha256  = local.script_pack_scaffold_services_sha256
    script_pack_agents_md_scaffold_sha256 = local.script_pack_agents_md_scaffold_sha256
    script_pack_runtime_deps_sha256       = local.script_pack_runtime_deps_sha256
    ubuntu_integration_home               = local.ubuntu_integration_home
  }

  monosplit_resolve_env_body = templatefile(
    "${path.module}/templates/monosplit-resolve-env.sh.tftpl",
    local.embed_template_vars_base,
  )
  monosplit_install_script_pack_body = templatefile(
    "${path.module}/templates/monosplit-install-script-pack.sh.tftpl",
    local.embed_template_vars_base,
  )

  embed_template_vars = merge(local.embed_template_vars_base, {
    monosplit_resolve_env_body         = local.monosplit_resolve_env_body
    monosplit_install_script_pack_body = local.monosplit_install_script_pack_body
  })

  template_vars_base = {
    module_prefix                         = local.module_prefix
    suffix                                = local.suffix
    ubuntu_tool_prefix                    = local.resolved_ubuntu_integration_name
    github_tool_prefix                    = local.resolved_github_integration_name
    cursor_tool_prefix                    = local.resolved_cursor_mcp_integration_name
    default_branch                        = trimspace(var.default_branch)
    default_split_strategy                = var.default_split_strategy
    max_recommended_services              = var.max_recommended_services
    script_pack_version                   = local.script_pack_version
    script_pack_runner_sha256             = local.script_pack_runner_sha256
    script_pack_boundary_scan_sha256      = local.script_pack_boundary_scan_sha256
    script_pack_clone_and_pr_sha256       = local.script_pack_clone_and_pr_sha256
    script_pack_scaffold_services_sha256  = local.script_pack_scaffold_services_sha256
    script_pack_agents_md_scaffold_sha256 = local.script_pack_agents_md_scaffold_sha256
    script_pack_runtime_deps_sha256       = local.script_pack_runtime_deps_sha256
    ubuntu_integration_home               = local.ubuntu_integration_home
    subagent_budgets                      = local.subagent_budgets
    enable_cursor_integration             = var.enable_cursor_integration
  }

  template_vars = merge(local.template_vars_base, {
    stage_runner_script                = local.stage_runner_script
    monosplit_resolve_env_body         = local.monosplit_resolve_env_body
    monosplit_install_script_pack_body = local.monosplit_install_script_pack_body
  })

  rendered_architect_persona = templatefile("${path.module}/personas/monorepo-split-architect.md.tftpl", local.template_vars)
  rendered_analyst_persona   = templatefile("${path.module}/personas/split-domain-analyst.md.tftpl", local.template_vars)

  rendered_templates = {
    for filename in fileset("${path.module}/templates", "*.md.tftpl") :
    replace(filename, ".tftpl", "") => templatefile("${path.module}/templates/${filename}", local.template_vars)
  }

  monosplit_scan_execute_series_body = templatefile(
    "${path.module}/templates/monosplit-scan-execute-series-embedded.sh.tftpl",
    local.embed_template_vars,
  )
  monosplit_guidance_pr_execute_series_body = templatefile(
    "${path.module}/templates/monosplit-guidance-pr-execute-series-embedded.sh.tftpl",
    local.embed_template_vars,
  )
  monosplit_scaffold_execute_series_body = templatefile(
    "${path.module}/templates/monosplit-scaffold-execute-series-embedded.sh.tftpl",
    local.embed_template_vars,
  )
  monosplit_extract_pr_execute_series_body = templatefile(
    "${path.module}/templates/monosplit-extract-pr-execute-series-embedded.sh.tftpl",
    local.embed_template_vars,
  )

  monosplit_scan_execute_series_b64        = base64encode(trimspace(local.monosplit_scan_execute_series_body))
  monosplit_guidance_pr_execute_series_b64 = base64encode(trimspace(local.monosplit_guidance_pr_execute_series_body))
  monosplit_scaffold_execute_series_b64    = base64encode(trimspace(local.monosplit_scaffold_execute_series_body))
  monosplit_extract_pr_execute_series_b64  = base64encode(trimspace(local.monosplit_extract_pr_execute_series_body))

  # Bootstrap B64 lives in Ubuntu integration env (tofu apply). Spawn context carries a short
  # decode command (~300 chars) so LLM runners paste reliably — inline ~9KB B64 pastes corrupt.
  monosplit_b64_decode_suffix = "tr -d '[:space:]' | base64 -d | bash"

  # Prefer *_B64_V2 keys to avoid partial env updates leaving decode scripts (expected hashes)
  # out of sync with the tarball. Fall back to V1 keys for backward compatibility.
  monosplit_scan_execute_series_decode_command        = "export WORK_ROOT='/home/integration/.{{workflow_run_id}}' WORKFLOW_RUN_ID='{{workflow_run_id}}' && if [ -n \"$MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2\" ]; then printf %s \"$MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2\" | ${local.monosplit_b64_decode_suffix}; exit 0; fi && if [ -z \"$MONOSPLIT_SCAN_EXECUTE_SERIES_B64\" ]; then echo monosplit_pack_error=missing_b64_env env=MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2; exit 1; fi && printf %s \"$MONOSPLIT_SCAN_EXECUTE_SERIES_B64\" | ${local.monosplit_b64_decode_suffix}"
  monosplit_guidance_pr_execute_series_decode_command = "export WORK_ROOT='/home/integration/.{{workflow_run_id}}' WORKFLOW_RUN_ID='{{workflow_run_id}}' && if [ -n \"$MONOSPLIT_GUIDANCE_PR_EXECUTE_SERIES_B64_V2\" ]; then printf %s \"$MONOSPLIT_GUIDANCE_PR_EXECUTE_SERIES_B64_V2\" | ${local.monosplit_b64_decode_suffix}; exit 0; fi && if [ -z \"$MONOSPLIT_GUIDANCE_PR_EXECUTE_SERIES_B64\" ]; then echo monosplit_pack_error=missing_b64_env env=MONOSPLIT_GUIDANCE_PR_EXECUTE_SERIES_B64_V2; exit 1; fi && printf %s \"$MONOSPLIT_GUIDANCE_PR_EXECUTE_SERIES_B64\" | ${local.monosplit_b64_decode_suffix}"
  monosplit_scaffold_execute_series_decode_command    = "export WORK_ROOT='/home/integration/.{{workflow_run_id}}' WORKFLOW_RUN_ID='{{workflow_run_id}}' && if [ -n \"$MONOSPLIT_SCAFFOLD_EXECUTE_SERIES_B64_V2\" ]; then printf %s \"$MONOSPLIT_SCAFFOLD_EXECUTE_SERIES_B64_V2\" | ${local.monosplit_b64_decode_suffix}; exit 0; fi && if [ -z \"$MONOSPLIT_SCAFFOLD_EXECUTE_SERIES_B64\" ]; then echo monosplit_pack_error=missing_b64_env env=MONOSPLIT_SCAFFOLD_EXECUTE_SERIES_B64_V2; exit 1; fi && printf %s \"$MONOSPLIT_SCAFFOLD_EXECUTE_SERIES_B64\" | ${local.monosplit_b64_decode_suffix}"
  monosplit_extract_pr_execute_series_decode_command  = "export WORK_ROOT='/home/integration/.{{workflow_run_id}}' WORKFLOW_RUN_ID='{{workflow_run_id}}' && if [ -n \"$MONOSPLIT_EXTRACT_PR_EXECUTE_SERIES_B64_V2\" ]; then printf %s \"$MONOSPLIT_EXTRACT_PR_EXECUTE_SERIES_B64_V2\" | ${local.monosplit_b64_decode_suffix}; exit 0; fi && if [ -z \"$MONOSPLIT_EXTRACT_PR_EXECUTE_SERIES_B64\" ]; then echo monosplit_pack_error=missing_b64_env env=MONOSPLIT_EXTRACT_PR_EXECUTE_SERIES_B64_V2; exit 1; fi && printf %s \"$MONOSPLIT_EXTRACT_PR_EXECUTE_SERIES_B64\" | ${local.monosplit_b64_decode_suffix}"

  # Line-anchored sentinels only — substring match on prose like "No `blocked:clone_failed`" false-positives the gate.
  scan_blocked_gate_match_regex = "(?m)(?:^blocked:|^stage_summary:clone-and-boundary-scan=blocked|^clone_blocker=|^work_root_error=|^script_pack_error=|^monosplit_pack_error=|^missing_b64_env|runner_sha256_mismatch|INFRA_HANDOFF|^boundary_scan_json_attached=false|^boundary_scan_ok=false|^boundary_scan_ok: false)"
  plan_blocked_gate_match_regex = "(?m)(?:^blocked:missing_plan_artifact|^blocked:plan_load_failed|^plan_loaded=false|^plan_loaded: false)"
}

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aios-agent-monorepo-services-splitter needs a GitHub Guild integration: provide github_secret_id or existing_github_integration_name / integration_names.github."
    }
  }
}

resource "terraform_data" "ubuntu_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_ubuntu_integration_name) != ""
      error_message = "aios-agent-monorepo-services-splitter needs an Ubuntu Guild integration: provision via github_secret_id or pass existing_ubuntu_integration_name / integration_names.ubuntu_cli."
    }
  }
}

resource "terraform_data" "cursor_integration_required" {
  count = var.enable_cursor_integration ? 1 : 0
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_cursor_mcp_integration_name) != ""
      error_message = "enable_cursor_integration=true requires non-empty existing_cursor_mcp_integration_name."
    }
  }
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by ${local.agent_architect_name} (issue/PR triage, gh api)."
}

module "ubuntu_integration" {
  count  = local.provision_ubuntu ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = compact([var.github_secret_id])
  install_tools    = ["gh", "git", "curl", "jq", "gdown", "cce"]
  env_vars = {
    MONOSPLIT_SCRIPT_PACK_VERSION               = local.script_pack_version
    MONOSPLIT_SCRIPT_PACK_TARBALL_B64           = local.monosplit_script_pack_tarball_b64
    MONOSPLIT_SCAN_EXECUTE_SERIES_B64           = local.monosplit_scan_execute_series_b64
    MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2        = local.monosplit_scan_execute_series_b64
    MONOSPLIT_GUIDANCE_PR_EXECUTE_SERIES_B64    = local.monosplit_guidance_pr_execute_series_b64
    MONOSPLIT_GUIDANCE_PR_EXECUTE_SERIES_B64_V2 = local.monosplit_guidance_pr_execute_series_b64
    MONOSPLIT_SCAFFOLD_EXECUTE_SERIES_B64       = local.monosplit_scaffold_execute_series_b64
    MONOSPLIT_SCAFFOLD_EXECUTE_SERIES_B64_V2    = local.monosplit_scaffold_execute_series_b64
    MONOSPLIT_EXTRACT_PR_EXECUTE_SERIES_B64     = local.monosplit_extract_pr_execute_series_b64
    MONOSPLIT_EXTRACT_PR_EXECUTE_SERIES_B64_V2  = local.monosplit_extract_pr_execute_series_b64
    MONOSPLIT_STAGE_RUNNER_SHA256               = local.script_pack_runner_sha256
    MONOSPLIT_BOUNDARY_SCAN_SHA256              = local.script_pack_boundary_scan_sha256
  }
}

resource "sg_policy" "monorepo_split_readonly_default" {
  name        = local.policy_readonly_name
  description = "PR-only delivery for monorepo split workflows — block push to default branch."
  type        = "intervention"
  rego_source = file("${path.module}/policies/monorepo-split-readonly-default.rego")
}

resource "sg_agent" "monorepo_split_architect" {
  name        = local.agent_architect_name
  persona     = local.rendered_architect_persona
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = ["web_search", "note", "notes_index", "read_notes"]
  }

  integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_ubuntu_integration_name,
  ])
}

resource "sg_agent" "split_domain_analyst" {
  name        = local.agent_analyst_name
  persona     = local.rendered_analyst_persona
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = ["web_search", "note", "notes_index", "read_notes"]
  }

  integrations = compact([
    local.resolved_github_integration_name,
  ])
}

resource "sg_agent" "cursor_split_executor" {
  count = var.enable_cursor_integration ? 1 : 0

  name        = local.agent_cursor_name
  persona     = templatefile("${path.module}/personas/cursor-split-executor.md", local.template_vars)
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_cursor_mcp_integration_name,
    local.resolved_github_integration_name,
  ])

  hitl = {
    always_allowed = [
      "web_search",
      "note",
      "notes_index",
      "read_notes",
      "${local.resolved_cursor_mcp_integration_name}_cursor_agents_get_status",
      "${local.resolved_cursor_mcp_integration_name}_cursor_agents_get_conversation",
    ]
  }
}

resource "sg_agent_budget" "monorepo_split_architect" {
  agent_name  = sg_agent.monorepo_split_architect.name
  limit_usd   = 25
  period_type = "daily"
}

resource "sg_agent_budget" "split_domain_analyst" {
  agent_name  = sg_agent.split_domain_analyst.name
  limit_usd   = 20
  period_type = "daily"
}

resource "sg_agent_budget" "cursor_split_executor" {
  count = var.enable_cursor_integration ? 1 : 0

  agent_name  = sg_agent.cursor_split_executor[0].name
  limit_usd   = 25
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "architect_dangerous_ops" {
  agent_name = sg_agent.monorepo_split_architect.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "architect_readonly_default" {
  agent_name = sg_agent.monorepo_split_architect.name
  policy_id  = sg_policy.monorepo_split_readonly_default.id
  enabled    = true
}

resource "sg_agent_policy_attachment" "analyst_dangerous_ops" {
  agent_name = sg_agent.split_domain_analyst.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "cursor_dangerous_ops" {
  count = var.enable_cursor_integration ? 1 : 0

  agent_name = sg_agent.cursor_split_executor[0].name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "cursor_shell_hitl" {
  count = (
    var.enable_cursor_integration &&
    try(var.policy_create_flags.container_shell_hitl, true) &&
    trimspace(try(var.policy_ids.container_shell_hitl, "")) != ""
  ) ? 1 : 0

  agent_name = sg_agent.cursor_split_executor[0].name
  policy_id  = var.policy_ids.container_shell_hitl
  enabled    = true
}

resource "sg_runbook_sop" "monorepo_split_orchestration" {
  name        = local.sop_orchestration_name
  approve     = true
  description = trimspace(local.rendered_templates["monorepo-split-orchestration.md"])
}

resource "sg_runbook_sop" "monorepo_clone_and_scan" {
  name        = local.sop_clone_scan_name
  approve     = true
  description = trimspace(local.rendered_templates["monorepo-clone-and-scan.md"])
}

resource "sg_runbook_sop" "bounded_context_analysis" {
  name        = local.sop_bounded_context_name
  approve     = true
  description = trimspace(local.rendered_templates["bounded-context-analysis.md"])
}

resource "sg_runbook_sop" "microservices_split_recommendation" {
  name        = local.sop_split_recommend_name
  approve     = true
  description = trimspace(local.rendered_templates["microservices-split-recommendation.md"])
}

resource "sg_runbook_sop" "split_guidance_pr" {
  name        = local.sop_guidance_pr_name
  approve     = true
  description = trimspace(local.rendered_templates["split-guidance-pr.md"])
}

resource "sg_runbook_sop" "split_extract_scaffold" {
  name        = local.sop_extract_scaffold_name
  approve     = true
  description = trimspace(local.rendered_templates["split-extract-scaffold.md"])
}

resource "sg_runbook_sop" "split_load_approved_plan" {
  name        = local.sop_load_plan_name
  approve     = true
  description = trimspace(local.rendered_templates["split-load-approved-plan.md"])
}

resource "sg_runbook_sop" "cursor_service_extraction" {
  count = var.enable_cursor_integration ? 1 : 0

  name        = local.sop_cursor_extract_name
  approve     = true
  description = trimspace(local.rendered_templates["cursor-service-extraction.md"])
}

resource "sg_evidence_checklist" "monorepo_split_analysis_evidence" {
  name        = local.evidence_analysis_name
  description = "Proof-of-work for monorepo split analysis: scan artifact, bounded contexts, catalog, migration phases, guidance PR."
  approve     = true
  required_items = [
    "boundary_scan_json_attached",
    "test_inventory_attached",
    "bounded_context_map_produced",
    "service_catalog_with_rationale",
    "per_service_test_strategy_documented",
    "migration_phases_documented",
    "guidance_pr_url",
  ]
  optional_items = ["coupling_hotspots", "risk_register", "baseline_test_run_evidence", "agents_md_produced"]
  scoring = {
    min_required         = 5
    confidence_threshold = 0.75
  }
  metadata = { playbook = "monorepo-services-split-analysis" }
}

resource "sg_evidence_checklist" "monorepo_split_extract_evidence" {
  name        = local.evidence_extract_name
  description = "Proof-of-work for monorepo split extract: scaffold layout and extract PR."
  approve     = true
  required_items = [
    "scaffold_layout_created",
    "per_service_test_strategy_documented",
    "extract_pr_url",
  ]
  optional_items = ["cursor_delegation_summary", "baseline_test_run_evidence", "scaffold_layout_validated"]
  scoring = {
    min_required         = 3
    confidence_threshold = 0.7
  }
  metadata = { playbook = "monorepo-services-split-extract" }
}

resource "sg_workflow" "monorepo_services_split_analysis" {
  name        = local.workflow_analysis_name
  domain      = "software-engineering"
  description = trimspace(local.rendered_templates["workflow-monorepo-split-analysis.md"])
  approve     = true

  metadata = local.workflow_execution_metadata

  required_inputs = ["github_repo_url"]
  optional_inputs = [
    "default_branch",
    "target_languages",
    "split_strategy",
    "max_recommended_services",
  ]
  evidence_checklist_ref = sg_evidence_checklist.monorepo_split_analysis_evidence.name

  example_queries = [
    "Analyze https://github.com/org/monorepo for microservices split — DDD bounded contexts",
    "We have a Go + TypeScript monolith — recommend service boundaries and open a guidance PR",
    "Split strategy team_topology for our Java monorepo — max 8 services",
  ]

  triggers = [
    { field = "intent", values = ["monorepo-split", "split-monorepo-services", "microservices-split-analysis"], type = "passive" },
  ]

  runbook_refs = [
    sg_runbook_sop.monorepo_split_orchestration.name,
    sg_runbook_sop.monorepo_clone_and_scan.name,
    sg_runbook_sop.bounded_context_analysis.name,
    sg_runbook_sop.microservices_split_recommendation.name,
    sg_runbook_sop.split_guidance_pr.name,
  ]

  stages = [
    { stage_id = "clone-and-boundary-scan", description = "Clone repo and run deterministic boundary scan", required = true },
    { stage_id = "scan-blocked-gate", description = "Skip to final gate when clone/scan fails", required = false },
    { stage_id = "analyze-coupling-and-contexts", description = "LLM bounded context analysis", required = true },
    { stage_id = "synthesize-split-plan", description = "Service catalog and migration phases", required = true },
    { stage_id = "open-guidance-pr", description = "Commit docs and open guidance PR", required = true },
    { stage_id = "final-evidence-gate", description = "Submit analysis evidence checklist", required = true },
  ]

  stage_bindings = [
    {
      stage_id  = "clone-and-boundary-scan"
      agent_ref = sg_agent.monorepo_split_architect.name
      runbook_refs = [
        sg_runbook_sop.monorepo_split_orchestration.name,
        sg_runbook_sop.monorepo_clone_and_scan.name,
      ]
      skill_refs = concat(
        ["monorepo-split-orchestration-sop", "monorepo-clone-and-scan-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-analysis::clone-and-boundary-scan"], []),
      )
      spawn_contracts = local.spawn_contracts_clone_and_scan
      note            = <<-EOT
        **Shared Ubuntu integration:** sidecars are **shared** across concurrent runs — agents cannot recycle pods, reprovision sidecars, or run `tofu apply`. All mutable state lives under `WORK_ROOT=/home/integration/.<workflow_run_id>/` (copy `workflow_run_id` from the stagerunner header). Never use `/home/integration/.monosplit-work` or other shared scratch paths.
        **Coordinator only:** resolve `github_repo_url` from inputs; if empty → `note blocked:missing_github_repo_url` and return without spawn.
        Spawn **exactly one** `clone-and-boundary-scan-runner`. Architect MUST NOT call ${local.resolved_ubuntu_integration_name}_execute_* directly.
        After runner: `note()` boundary_scan_json_path, boundary_scan_json_attached, **boundary_scan_summary** (compact JSON from runner stdout), test_inventory_attached, test_confidence_score, runtime_deps_provisioned, baseline_test_status, baseline_test_run_evidence, script_pack_version=${local.script_pack_version}. Bootstrap installs JDK/Go/Node via apt (runners have root/sudo) — never defer baseline tests with "Java not available in runner env".
        If runner stdout contains `71WORK_ROOT`/`79WORK_ROOT` or `clone_blocker=wrong_shell_dollar_escape`: note the sentinel, re-spawn **once** with `SCAN_EXECUTE_SERIES_DECODE_COMMAND` pasted verbatim (single `$` only — never `$$`).
        If runner stdout contains `script_pack_error=runner_sha256_mismatch` (or any `script_pack_error=*_sha256_mismatch`): `note blocked:runner_failed` and `stage_summary:clone-and-boundary-scan=blocked`. Give the user an **INFRA_HANDOFF** table: workflow_run_id, script_pack_version=${local.script_pack_version}, expected SHA-256 `${local.script_pack_runner_sha256}`, actual from runner stderr. Tell them to contact the **platform/infra team** that provisions the Ubuntu sidecar — **do not** tell them to recycle sidecars or re-apply tofu manually. After the sidecar is re-provisioned with matching env, they should **start a new workflow run** (new `workflow_run_id`).
        If runner fails for other reasons after one re-spawn → `note blocked:runner_failed` and **stop** — never substitute domain knowledge or invent scan results.
        Mirror keys to `$HOME/.<workflow_run_id>/notes.json`.
      EOT
    },
    {
      stage_id         = "scan-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["clone-and-boundary-scan"]
      action_config = {
        condition = "output_matches_regex"
        match     = local.scan_blocked_gate_match_regex
        skip_to   = "final-evidence-gate"
        reason    = "Clone or boundary scan failure — skip analyst and PR stages"
      }
    },
    {
      stage_id         = "analyze-coupling-and-contexts"
      agent_ref        = sg_agent.split_domain_analyst.name
      stage_depends_on = ["scan-blocked-gate"]
      runbook_refs = [
        sg_runbook_sop.bounded_context_analysis.name,
        sg_runbook_sop.monorepo_split_orchestration.name,
      ]
      skill_refs = concat(
        ["bounded-context-analysis-sop", "monorepo-split-orchestration-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-analysis::analyze-coupling-and-contexts"], []),
      )
      note = "Use `boundary_scan_summary` from notes (or `read_notes`) for test_inventory and module facts — do not rely on sidecar file paths. **Require** `boundary_scan_json_attached=true` and `boundary_scan_summary` — if missing or upstream `blocked:*`, note `blocked:missing_scan_artifact` and stop; never invent repo structure from training data. Produce bounded context map with test coverage mapping; note bounded_context_map_produced=true. No shell."
    },
    {
      stage_id         = "synthesize-split-plan"
      agent_ref        = sg_agent.split_domain_analyst.name
      stage_depends_on = ["analyze-coupling-and-contexts"]
      runbook_refs = [
        sg_runbook_sop.microservices_split_recommendation.name,
        sg_runbook_sop.monorepo_split_orchestration.name,
      ]
      skill_refs = concat(
        ["microservices-split-recommendation-sop", "monorepo-split-orchestration-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-analysis::synthesize-split-plan"], []),
      )
      note = "Emit service-catalog.yaml + migration-phases + per-service test strategy. Draft **AGENTS.md** sections: `note(key=agents_md_analyst_sections)` with project purpose, DDD bounded contexts, and conventions observed in code (for IDE agents — https://agents.md/). note service_catalog_with_rationale=true migration_phases_documented=true per_service_test_strategy_documented=true."
    },
    {
      stage_id         = "open-guidance-pr"
      agent_ref        = sg_agent.monorepo_split_architect.name
      stage_depends_on = ["synthesize-split-plan"]
      runbook_refs = [
        sg_runbook_sop.split_guidance_pr.name,
        sg_runbook_sop.monorepo_split_orchestration.name,
      ]
      skill_refs = concat(
        ["split-guidance-pr-sop", "monorepo-split-orchestration-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-analysis::open-guidance-pr"], []),
      )
      spawn_contracts = local.spawn_contracts_guidance_pr
      note            = "Spawn guidance-pr-runner only. After runner note guidance_pr_url and agents_md_produced=true. PR includes repo-root AGENTS.md (https://agents.md/) plus docs/architecture/. PR-only — never push ${trimspace(var.default_branch)}."
    },
    {
      stage_id         = "final-evidence-gate"
      agent_ref        = sg_agent.monorepo_split_architect.name
      stage_depends_on = ["open-guidance-pr"]
      runbook_refs     = [sg_runbook_sop.monorepo_split_orchestration.name]
      skill_refs = concat(
        ["monorepo-split-orchestration-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-analysis::final-evidence-gate"], []),
      )
      note = "submit_evidence for monorepo-split-analysis-evidence checklist. If blocked upstream, note `stage_summary:final-evidence-gate=blocked` only — never instruct operator to recycle sidecars, re-apply tofu, or abandon the current workflow_run_id."
    },
  ]
}

resource "sg_workflow" "monorepo_services_split_extract" {
  name        = local.workflow_extract_name
  domain      = "software-engineering"
  description = trimspace(local.rendered_templates["workflow-monorepo-split-extract.md"])
  approve     = true

  metadata = local.workflow_execution_metadata

  required_inputs = ["github_repo_url", "plan_artifact_path"]
  optional_inputs = [
    "prior_workflow_run_id",
    "split_mode",
    "target_service_names",
    "default_branch",
  ]
  evidence_checklist_ref = sg_evidence_checklist.monorepo_split_extract_evidence.name

  example_queries = [
    "Extract services from approved plan at docs/architecture/service-catalog.yaml",
    "Scaffold_only split for billing and orders services from prior analysis run",
  ]

  triggers = [
    { field = "intent", values = ["monorepo-split-extract", "scaffold-microservices"], type = "passive" },
  ]

  runbook_refs = compact([
    sg_runbook_sop.monorepo_split_orchestration.name,
    sg_runbook_sop.split_load_approved_plan.name,
    sg_runbook_sop.split_extract_scaffold.name,
    sg_runbook_sop.split_guidance_pr.name,
    var.enable_cursor_integration ? sg_runbook_sop.cursor_service_extraction[0].name : "",
  ])

  stages = [
    { stage_id = "load-approved-plan", description = "Load plan artifacts from analysis run or path (notes/MCP only)", required = true },
    { stage_id = "plan-blocked-gate", description = "Skip extract when no approved plan artifact", required = false },
    { stage_id = "scaffold-service-layout", description = "Ubuntu scaffold services/<name>/", required = true },
    { stage_id = "cursor-skip-gate", description = "Skip Cursor stage when disabled or scaffold_only", required = false },
    { stage_id = "cursor-refactor-services", description = "Optional Cursor refactor on extract branch", required = false },
    { stage_id = "open-extract-pr", description = "Open PR with scaffolded layout", required = true },
    { stage_id = "extract-evidence-gate", description = "Submit extract evidence checklist", required = true },
  ]

  stage_bindings = [
    {
      stage_id  = "load-approved-plan"
      agent_ref = sg_agent.monorepo_split_architect.name
      runbook_refs = [
        sg_runbook_sop.split_load_approved_plan.name,
        sg_runbook_sop.monorepo_split_orchestration.name,
      ]
      skill_refs = concat(
        ["split-load-approved-plan-sop", "monorepo-split-orchestration-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-extract::load-approved-plan"], []),
      )
      note = "Notes/MCP only — NO create_agent, NO Ubuntu runners, NO inline shell. read_notes plan_artifact_path prior_workflow_run_id guidance_pr_url. If both plan path and prior run id missing after read_notes → note blocked:missing_plan_artifact + extract_blocked_reason, note plan_loaded=false, STOP. Else note plan_loaded=true and mirror service-catalog.yaml path. Never re-run analysis or boundary scan here."
    },
    {
      stage_id         = "plan-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["load-approved-plan"]
      action_config = {
        condition = "output_matches_regex"
        match     = local.plan_blocked_gate_match_regex
        skip_to   = "extract-evidence-gate"
        reason    = "No approved plan — skip scaffold, Cursor, and extract PR stages"
      }
    },
    {
      stage_id         = "scaffold-service-layout"
      agent_ref        = sg_agent.monorepo_split_architect.name
      stage_depends_on = ["plan-blocked-gate"]
      runbook_refs = [
        sg_runbook_sop.split_extract_scaffold.name,
        sg_runbook_sop.monorepo_split_orchestration.name,
      ]
      skill_refs = concat(
        ["split-extract-scaffold-sop", "monorepo-split-orchestration-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-extract::scaffold-service-layout"], []),
      )
      spawn_contracts = local.spawn_contracts_scaffold_services
      note            = "Spawn scaffold-services-runner ONLY (paste SCAFFOLD_EXECUTE_SERIES_DECODE_COMMAND). NEVER gh pr create, NEVER open extract PR in this stage. After runner: note scaffold_layout_created and scaffold_layout_validated from runner stdout only."
    },
    {
      stage_id         = "cursor-refactor-services"
      agent_ref        = var.enable_cursor_integration ? sg_agent.cursor_split_executor[0].name : sg_agent.monorepo_split_architect.name
      stage_depends_on = ["cursor-skip-gate"]
      runbook_refs = var.enable_cursor_integration ? [
        sg_runbook_sop.cursor_service_extraction[0].name,
        sg_runbook_sop.monorepo_split_orchestration.name,
      ] : [sg_runbook_sop.monorepo_split_orchestration.name]
      skill_refs = concat(
        var.enable_cursor_integration ? ["cursor-service-extraction-sop"] : [],
        ["monorepo-split-orchestration-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-extract::cursor-refactor-services"], []),
      )
      note = var.enable_cursor_integration ? "Cursor agent: delegate refactor per cursor-service-extraction-sop. note cursor_delegation_summary when done." : "Skipped when Cursor disabled — conditional_skip gate handles routing."
    },
    {
      stage_id         = "cursor-skip-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["scaffold-service-layout"]
      action_config = {
        condition = "output_matches_regex"
        match     = "split_mode=scaffold_only|enable_cursor_integration=false"
        skip_to   = "open-extract-pr"
        reason    = "Skip Cursor stage when disabled or scaffold_only"
      }
    },
    {
      stage_id         = "open-extract-pr"
      agent_ref        = sg_agent.monorepo_split_architect.name
      stage_depends_on = ["cursor-refactor-services"]
      runbook_refs = [
        sg_runbook_sop.split_guidance_pr.name,
        sg_runbook_sop.monorepo_split_orchestration.name,
      ]
      skill_refs = concat(
        ["split-guidance-pr-sop", "monorepo-split-orchestration-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-extract::open-extract-pr"], []),
      )
      spawn_contracts = local.spawn_contracts_extract_pr
      note            = "Spawn extract-pr-runner ONLY after scaffold_layout_validated=true in notes. NEVER open PR without runner. note extract_pr_url from runner notes only."
    },
    {
      stage_id         = "extract-evidence-gate"
      agent_ref        = sg_agent.monorepo_split_architect.name
      stage_depends_on = ["open-extract-pr"]
      runbook_refs     = [sg_runbook_sop.monorepo_split_orchestration.name]
      skill_refs = concat(
        ["monorepo-split-orchestration-sop"],
        try(var.workflow_skill_refs["monorepo-services-split-extract::extract-evidence-gate"], []),
      )
      note = "submit_evidence for monorepo-split-extract-evidence. Require scaffold_layout_validated=true and extract_pr_url in notes when extract ran. When plan-blocked-gate skipped here, document blocked:missing_plan_artifact — do not claim scaffold or PR success."
    },
  ]
}

resource "sg_webhook" "github_monorepo_split" {
  count = var.enable_github_webhook ? 1 : 0

  name        = local.webhook_name
  target_type = "workflow"
  target_name = sg_workflow.monorepo_services_split_analysis.name
  action      = "GitHub issue or PR about splitting a monorepo into microservices; triage and run monorepo-services-split-analysis with github_repo_url from the body."
  enabled     = true
}
