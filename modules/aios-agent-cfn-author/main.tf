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

locals {
  module_prefix = "cfn-author"
  suffix        = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_author_name        = "cfn-author${local.suffix}"
  agent_drift_name         = "cfn-drift-manager${local.suffix}"
  workflow_intent_name     = "intent-to-infrastructure${local.suffix}"
  workflow_drift_name      = "cloudformation-drift-management${local.suffix}"
  workflow_compliance_name = "cfn-contextual-compliance${local.suffix}"
  workflow_governed_name   = "cfn-governed-deployment${local.suffix}"
  webhook_intent_name      = "cfn-intent-to-infrastructure${local.suffix}"
  webhook_compliance_name  = "cfn-contextual-compliance${local.suffix}"
  webhook_drift_name       = "cfn-drift-management${local.suffix}"

  resolved_workspace = {
    workspace_id         = coalesce(trimspace(try(var.workspace.workspace_id, "")), var.target_repository_full_name)
    source_type          = coalesce(try(var.workspace.source_type, ""), "git")
    repository_full_name = coalesce(trimspace(try(var.workspace.repository_full_name, "")), var.target_repository_full_name)
    base_branch          = coalesce(trimspace(try(var.workspace.base_branch, "")), var.target_base_branch)
    path_prefix          = coalesce(trimspace(try(var.workspace.path_prefix, "")), var.cfn_template_path_prefix)
    s3_bucket            = trimspace(try(var.workspace.s3_bucket, ""))
    s3_prefix            = trimspace(try(var.workspace.s3_prefix, ""))
    primary_iac          = coalesce(try(var.workspace.primary_iac, ""), "cloudformation")
    self_healing_allowed = try(var.workspace.self_healing_allowed, false)
    force_new_workspace  = try(var.workspace.force_new_workspace, false)
  }
  sop_orchestration_name = "cfn-orchestration-sop${local.suffix}"

  sop_parse_requirements_name  = "cfn-parse-requirements${local.suffix}"
  sop_generate_template_name   = "cfn-generate-template${local.suffix}"
  sop_validate_template_name   = "cfn-validate-template${local.suffix}"
  sop_security_guardrails_name = "cfn-security-guardrails${local.suffix}"
  sop_open_pr_name             = "cfn-open-pr${local.suffix}"
  sop_architecture_fit_name    = "cfn-architecture-fit-review${local.suffix}"
  sop_preview_changes_name     = "cfn-preview-changes${local.suffix}"
  sop_final_intent_name        = "cfn-final-intent-summary${local.suffix}"
  sop_compliance_check_name    = "cfn-compliance-check-inline${local.suffix}"
  sop_parse_drift_scope_name   = "cfn-parse-drift-scope${local.suffix}"
  sop_normalize_drift_name     = "cfn-normalize-drift-ingress${local.suffix}"
  sop_inventory_stacks_name    = "cfn-inventory-stacks${local.suffix}"
  sop_parallel_drift_name      = "cfn-parallel-detect-drift${local.suffix}"
  sop_synthesize_drift_name    = "cfn-synthesize-drift-report${local.suffix}"
  sop_classify_drift_name      = "cfn-classify-drift-recommendation${local.suffix}"
  sop_reconcile_diff_name      = "cfn-reconcile-template-diff${local.suffix}"
  sop_open_reconcile_name      = "cfn-open-reconcile-pr${local.suffix}"
  sop_final_drift_name         = "cfn-final-drift-summary${local.suffix}"

  evidence_intent_name = "cfn-intent-to-infrastructure-evidence${local.suffix}"
  evidence_drift_name  = "cfn-drift-management-evidence${local.suffix}"

  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  aws_integration_name    = "${local.module_prefix}-aws${local.suffix}"
  ubuntu_integration_name = "${local.module_prefix}-ubuntu${local.suffix}"

  provision_github = trimspace(var.existing_github_integration_name) == "" && trimspace(var.github_secret_id) != ""
  provision_aws    = trimspace(var.existing_aws_integration_name) == ""

  create_ubuntu_integration = (
    var.enable_ubuntu_cli || var.create_remote_runner
  ) && trimspace(var.existing_ubuntu_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )

  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )

  resolved_ubuntu_integration_name = coalesce(
    trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : null,
    try(module.ubuntu_integration[0].integration_name, null),
    "",
  )

  agent_integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_ubuntu_integration_name != "" ? local.resolved_ubuntu_integration_name : null,
  ])

  remote_runner_names = (
    var.create_remote_runner
    && var.remote_runner_attach_to_agent
    && length(module.remote_runner) > 0
  ) ? toset([module.remote_runner[0].runner_name]) : null

  template_vars = {
    target_repository_full_name    = var.target_repository_full_name
    target_base_branch             = var.target_base_branch
    cfn_template_path_prefix       = var.cfn_template_path_prefix
    cfn_template_catalog_path      = var.cfn_template_catalog_path
    default_aws_regions            = jsonencode(var.default_aws_regions)
    drift_detection_batch_size     = var.drift_detection_batch_size
    allow_prod_change_set_preview  = var.allow_prod_change_set_preview
    org_baseline_name              = var.org_baseline_name
    fedramp_profile                = var.fedramp_profile
    knowledge_base_path            = var.knowledge_base_path
    deployment_process_doc         = var.deployment_process_doc
    workspace_id                   = local.resolved_workspace.workspace_id
    workspace_source_type          = local.resolved_workspace.source_type
    workspace_repository           = local.resolved_workspace.repository_full_name
    workspace_base_branch          = local.resolved_workspace.base_branch
    workspace_path_prefix          = local.resolved_workspace.path_prefix
    workspace_s3_bucket            = local.resolved_workspace.s3_bucket
    workspace_s3_prefix            = local.resolved_workspace.s3_prefix
    workspace_primary_iac          = local.resolved_workspace.primary_iac
    workspace_self_healing_allowed = local.resolved_workspace.self_healing_allowed ? "true" : "false"
    workspace_force_new            = local.resolved_workspace.force_new_workspace ? "true" : "false"
    policy_scan_enabled            = var.enable_security_guardrails_gate ? "true" : "false"
  }

  change_set_safety_rego = trimspace(templatefile("${path.module}/templates/change-set-safety-gate.rego.tftpl", {
    allow_prod_change_set_preview = var.allow_prod_change_set_preview ? "true" : "false"
  }))

  attach_prod_write_gate = try(var.policy_create_flags.prod_write_gate, true)

  preview_disabled_gate_match = var.enable_change_set_preview ? "cfn_author_preview_disabled_gate_never_match" : "."
  preview_skip_gate_match     = "confirm_deploy=false|confirm_deploy[^\\n]{0,30}false|\"confirm_deploy\"\\s*:\\s*false|\"confirm_deploy\"\\s*:\\s*\"false\"|confirm_deploy[^\\n]{0,30}absent"
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration for ${local.agent_author_name} (template catalog, PRs, drift reconcile)."
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  aws_role_arn       = var.aws_role_arn
  aws_region         = var.aws_region
  existing_secret_id = var.aws_secret_id
  description        = "AWS integration for ${local.agent_author_name} (CFN validate, change-set preview, drift)."
}

module "remote_runner" {
  count  = trimspace(var.remote_runner_name) != "" ? 1 : 0
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = trimspace(var.remote_runner_name)
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_author_name} (cfn-lint / shell)."
  labels        = var.remote_runner_labels
}

module "governance_runbooks" {
  source = "../aios-cfn-governance-runbooks"

  name_suffix               = var.name_suffix
  org_baseline_name         = var.org_baseline_name
  fedramp_profile           = var.fedramp_profile
  knowledge_base_path       = var.knowledge_base_path
  deployment_process_doc    = var.deployment_process_doc
  cfn_template_catalog_path = var.cfn_template_catalog_path
}

module "ubuntu_integration" {
  count  = local.create_ubuntu_integration ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = compact(concat(var.ubuntu_secret_ref_ids, [var.github_secret_id]))
  install_tools = [
    "curl", "git", "gh", "jq", "python3-pip", "awscli",
  ]
  pip_packages = [
    "cfn-lint>=1.19.0",
    "checkov==3.2.340",
  ]
  env_vars = merge(
    {
      CFN_AUTHOR_SCRIPT_PACK_VERSION     = local.script_pack_version
      CFN_AUTHOR_SCRIPT_PACK_TARBALL_B64 = local.script_pack_tarball_b64
      CFN_AUTHOR_STAGE_RUNNER_SHA256     = local.script_pack_stage_runner_sha256
      CFN_AUTHOR_DEFAULT_REPO            = var.target_repository_full_name
      CFN_AUTHOR_DEFAULT_BRANCH          = var.target_base_branch
      CFN_AUTHOR_TEMPLATE_PREFIX         = var.cfn_template_path_prefix
      CFN_AUTHOR_SKIP_GUARDRAILS         = var.enable_security_guardrails_gate ? "0" : "1"
      CFN_AUTHOR_MAX_TEMPLATE_LINES      = tostring(var.max_template_lines)
      CFN_AUTHOR_CATALOG_PATH            = var.cfn_template_catalog_path
    },
  )
}

module "drift_schedule" {
  count  = var.enable_drift_schedule ? 1 : 0
  source = "../aios-agent-schedules"

  target_type = "workflow"
  target_name = sg_workflow.cloudformation_drift_management.name

  schedules = [
    {
      name       = "cfn-drift-management-periodic${local.suffix}"
      expression = var.drift_schedule_cron
      action     = "Run CloudFormation drift management across configured regions. Classify drift as FIX_DRIFT (risk), INCORPORATE_VIA_PR (valid desired state), or IGNORE. Open reconcile PR when enabled."
      enabled    = true
    },
  ]
}

resource "terraform_data" "shell_runner_integration_required" {
  lifecycle {
    precondition {
      condition = (
        (var.create_remote_runner && var.remote_runner_attach_to_agent && trimspace(var.remote_runner_name) != "")
        || trimspace(local.resolved_ubuntu_integration_name) != ""
      )
      error_message = "Spawn contracts require Ubuntu CLI or remote runner: set enable_ubuntu_cli or existing_ubuntu_integration_name, or configure create_remote_runner + remote_runner_attach_to_agent + remote_runner_name."
    }
  }
}

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aios-agent-cfn-author needs GitHub: provide github_secret_id or existing_github_integration_name."
    }
  }
}

resource "terraform_data" "aws_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_aws_integration_name) != ""
      error_message = "aios-agent-cfn-author needs AWS: provide existing_aws_integration_name or aws_role_arn / aws_secret_id to provision internal AWS integration."
    }
  }
}

resource "terraform_data" "aws_integration_provision_inputs" {
  count = local.provision_aws ? 1 : 0

  lifecycle {
    precondition {
      condition     = trimspace(var.aws_role_arn) != "" || trimspace(var.aws_secret_id) != ""
      error_message = "When existing_aws_integration_name is empty, set exactly one of aws_role_arn or aws_secret_id for the internal AWS integration."
    }
    precondition {
      condition     = !(trimspace(var.aws_role_arn) != "" && trimspace(var.aws_secret_id) != "")
      error_message = "aios-agent-cfn-author cannot accept both aws_role_arn and aws_secret_id; pass only one when provisioning internal AWS integration."
    }
  }
}

resource "terraform_data" "github_integration_provision_inputs" {
  count = local.provision_github ? 1 : 0

  lifecycle {
    precondition {
      condition     = trimspace(var.github_secret_id) != ""
      error_message = "When existing_github_integration_name is empty, github_secret_id is required to provision internal GitHub integration."
    }
  }
}

resource "terraform_data" "remote_runner_name_required" {
  count = var.create_remote_runner ? 1 : 0

  lifecycle {
    precondition {
      condition     = trimspace(var.remote_runner_name) != ""
      error_message = "remote_runner_name is required when create_remote_runner is true."
    }
  }
}

resource "sg_agent" "cfn_author" {
  name        = local.agent_author_name
  persona     = file("${path.module}/personas/cfn-author.md")
  model_names = compact(var.model_names)

  integrations   = local.agent_integrations
  remote_runners = local.remote_runner_names

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }
}

resource "sg_agent" "cfn_drift_manager" {
  name        = local.agent_drift_name
  persona     = file("${path.module}/personas/cfn-drift-manager.md")
  model_names = compact(var.model_names)

  integrations   = local.agent_integrations
  remote_runners = local.remote_runner_names

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }
}

resource "sg_agent_budget" "cfn_author" {
  agent_name  = sg_agent.cfn_author.name
  limit_usd   = var.agent_budget_usd_daily
  period_type = "daily"
}

resource "sg_agent_budget" "cfn_drift_manager" {
  agent_name  = sg_agent.cfn_drift_manager.name
  limit_usd   = var.agent_budget_usd_daily
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "cfn_author_dangerous_ops" {
  agent_name = sg_agent.cfn_author.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "cfn_drift_manager_dangerous_ops" {
  agent_name = sg_agent.cfn_drift_manager.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "cfn_author_prod_write_gate" {
  count      = local.attach_prod_write_gate ? 1 : 0
  agent_name = sg_agent.cfn_author.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_agent_policy_attachment" "cfn_drift_manager_prod_write_gate" {
  count      = local.attach_prod_write_gate ? 1 : 0
  agent_name = sg_agent.cfn_drift_manager.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_runbook_sop" "cfn_orchestration" {
  name        = local.sop_orchestration_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cfn-orchestration-sop.md.tftpl", local.template_vars))
}

resource "sg_runbook_sop" "parse_requirements" {
  name    = local.sop_parse_requirements_name
  approve = true
  description = trimspace(join("\n\n", [
    templatefile("${path.module}/templates/runbook-parse-requirements.md", local.template_vars),
    "## Inline: cfn-developer-intent-handler (do not load_skill on parse-intent)",
    trimspace(file("${path.module}/skills/cfn-developer-intent-handler.md")),
  ]))
}

resource "sg_runbook_sop" "generate_template" {
  name    = local.sop_generate_template_name
  approve = true
  description = trimspace(join("\n\n", [
    templatefile("${path.module}/templates/runbook-generate-template.md", merge(local.template_vars, {
      max_template_lines = var.max_template_lines
    })),
    "## Inline: cfn-company-best-practices (do not load_skill — rules are below)",
    trimspace(file("${path.module}/skills/cfn-company-best-practices.md")),
    "## Inline: cfn-template-catalog-discovery",
    trimspace(file("${path.module}/skills/cfn-template-catalog-discovery.md")),
  ]))
}

resource "sg_runbook_sop" "validate_template" {
  name        = local.sop_validate_template_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-validate-template.md"))
}

resource "sg_runbook_sop" "security_guardrails" {
  name        = local.sop_security_guardrails_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-security-guardrails.md", local.template_vars))
}

resource "sg_runbook_sop" "architecture_fit_review" {
  name    = local.sop_architecture_fit_name
  approve = true
  description = trimspace(join("\n\n", [
    file("${path.module}/templates/runbook-architecture-fit-review.md"),
    "## Inline: cfn-architecture-fit-review (do not load_skill)",
    trimspace(file("${path.module}/skills/cfn-architecture-fit-review.md")),
  ]))
}

resource "sg_runbook_sop" "open_pr" {
  name        = local.sop_open_pr_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-open-pr.md", local.template_vars))
}

resource "sg_runbook_sop" "preview_changes" {
  name        = local.sop_preview_changes_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-preview-changes.md"))
}

resource "sg_runbook_sop" "compliance_check_inline" {
  name        = local.sop_compliance_check_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-compliance-check-inline.md"))
}

resource "sg_runbook_sop" "final_intent_summary" {
  name        = local.sop_final_intent_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-final-intent-summary.md"))
}

resource "sg_runbook_sop" "normalize_drift_ingress" {
  name        = local.sop_normalize_drift_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-normalize-drift-ingress.md", local.template_vars))
}

resource "sg_runbook_sop" "parse_drift_scope" {
  name        = local.sop_parse_drift_scope_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-parse-drift-scope.md", local.template_vars))
}

resource "sg_runbook_sop" "inventory_stacks" {
  name        = local.sop_inventory_stacks_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-inventory-stacks.md"))
}

resource "sg_runbook_sop" "parallel_detect_drift" {
  name        = local.sop_parallel_drift_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-parallel-detect-drift.md", local.template_vars))
}

resource "sg_runbook_sop" "synthesize_drift_report" {
  name        = local.sop_synthesize_drift_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-synthesize-drift-report.md"))
}

resource "sg_runbook_sop" "classify_drift_recommendation" {
  name        = local.sop_classify_drift_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-classify-drift-recommendation.md"))
}

resource "sg_runbook_sop" "reconcile_template_diff" {
  name        = local.sop_reconcile_diff_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-reconcile-template-diff.md", local.template_vars))
}

resource "sg_runbook_sop" "open_reconcile_pr" {
  name        = local.sop_open_reconcile_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-open-reconcile-pr.md"))
}

resource "sg_runbook_sop" "final_drift_summary" {
  name        = local.sop_final_drift_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-final-drift-summary.md"))
}

resource "sg_evidence_checklist" "intent_to_infrastructure" {
  count       = var.enable_evidence_checklist ? 1 : 0
  name        = local.evidence_intent_name
  description = "Proof-of-work for intent-to-infrastructure: catalog-aware template, validation, PR, optional change-set preview."
  approve     = true
  required_items = [
    "requirements_parsed",
    "template_generated",
    "cfn_lint_passed",
    "validate_template_passed",
    "pr_opened",
  ]
  optional_items = ["change_set_preview_documented", "architecture_lint_passed", "architecture_needs_review"]
  scoring = {
    min_required         = 4
    confidence_threshold = 0.70
  }
  metadata = { playbook = "intent-to-infrastructure" }
}

resource "sg_evidence_checklist" "drift_management" {
  count       = var.enable_evidence_checklist ? 1 : 0
  name        = local.evidence_drift_name
  description = "Proof-of-work for drift management: inventory, scan, classification, optional reconcile PR."
  approve     = true
  required_items = [
    "stacks_inventoried",
    "drift_scan_complete",
    "drift_report_documented",
  ]
  optional_items = ["reconcile_pr_opened"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.70
  }
  metadata = { playbook = "cloudformation-drift-management" }
}

resource "sg_workflow" "intent_to_infrastructure" {
  name        = local.workflow_intent_name
  domain      = "platform-engineering"
  description = trimspace(templatefile("${path.module}/templates/workflow-intent-to-infrastructure.md", local.template_vars))
  approve     = true

  evidence_checklist_ref = var.enable_evidence_checklist ? sg_evidence_checklist.intent_to_infrastructure[0].name : null

  metadata = {
    planner_max_tool_iterations       = "10"
    terminal_calling_halguard_mode    = "paste_only_minimal_planner"
    halguard_skip_subagent_task_types = "terminal_calling"
  }

  triggers = [
    { field = "source", values = ["webhook"], type = "active", source = "webhook" },
    { field = "incident_title_contains", values = ["cloudformation", "generate template", "intent to infra", "cfn", "stack template"], type = "passive" },
  ]

  required_inputs = []
  optional_inputs = ["intent", "request", "description", "stack_name", "environment", "template_file_name", "catalog_repo", "github_repo_override", "workspace_id", "correlation_id", "confirm_deploy", "target_rps", "sla_availability", "p99_latency_ms", "workload_class"]

  runbook_refs = concat(
    [
      sg_runbook_sop.cfn_orchestration.name,
      sg_runbook_sop.parse_requirements.name,
      sg_runbook_sop.generate_template.name,
      sg_runbook_sop.validate_template.name,
      sg_runbook_sop.security_guardrails.name,
      sg_runbook_sop.architecture_fit_review.name,
      sg_runbook_sop.open_pr.name,
      sg_runbook_sop.preview_changes.name,
      sg_runbook_sop.final_intent_summary.name,
    ],
    module.governance_runbooks.runbook_names_list,
  )

  example_queries = [
    "Generate an S3 bucket with versioning in us-east-1 and open a PR; preview against stack staging-data",
    "Intent to infrastructure: add a private RDS instance following our catalog patterns",
    "Create CloudFormation for a VPC with public and private subnets using company best practices",
  ]

  stages = [
    { stage_id = "parse-intent", description = "Parse intent and normalize webhook/API ingress.", required = true },
    { stage_id = "intent-blocked-gate", description = "Skip when intent incomplete.", required = true },
    { stage_id = "compliance-check", description = "FedRAMP and org baseline review.", required = true },
    { stage_id = "compliance-blocked-gate", description = "Skip when compliance hard-fails.", required = true },
    { stage_id = "synthesize-template", description = "Generate and harden CFN from catalog.", required = true },
    { stage_id = "quality-check", description = "cfn-lint, guardrails, validate-template.", required = true },
    { stage_id = "quality-rework-loop", description = "Loop to synthesize-template on lint failure.", required = true },
    { stage_id = "quality-blocked-gate", description = "Skip PR when quality checks fail.", required = true },
    { stage_id = "architecture-fit-review", description = "Post-synthesis NFR and architecture lint.", required = true },
    { stage_id = "architecture-blocked-gate", description = "Skip PR when architecture lint FAIL.", required = true },
    { stage_id = "open-pr", description = "Governed deployment check and GitHub PR.", required = true },
    { stage_id = "publish-blocked-gate", description = "Skip preview when PR blocked.", required = true },
    { stage_id = "preview-disabled-gate", description = "Skip preview when change-set preview disabled in module config.", required = true },
    { stage_id = "preview-skip-gate", description = "Skip preview when confirm_deploy false.", required = true },
    { stage_id = "preview-safety-gate", description = "Rego prod change-set guard.", required = true },
    { stage_id = "preview-changes", description = "Change-set describe preview on PR.", required = true },
    { stage_id = "final-intent-summary", description = "Developer-facing summary.", required = true },
  ]

  stage_bindings = [
    {
      stage_id        = "parse-intent"
      agent_ref       = sg_agent.cfn_author.name
      runbook_refs    = [sg_runbook_sop.parse_requirements.name]
      spawn_contracts = local.spawn_contracts_intent_parse_requirements
      skill_refs      = try(var.workflow_skill_refs["intent-to-infrastructure::parse-intent"], [])
      note            = "Spawn parse-requirements-runner once (ONE execute_series: write stage_input.raw + parse-requirements). Parent FORBIDDEN: load_skill, read_notes, notes_index, re-spawn on success. Stage output ≤6 structured lines only."
    },
    {
      stage_id         = "intent-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["parse-intent"]
      action_config = {
        condition = "output_matches_regex"
        match     = "requirements_blocked=true|requirements_blocked:\\s*true"
        skip_to   = "final-intent-summary"
        reason    = "Requirements incomplete — skip generation and PR"
      }
    },
    {
      stage_id         = "compliance-check"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["intent-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.compliance_check_inline.name]
      spawn_contracts  = local.spawn_contracts_intent_compliance_check
      skill_refs       = try(var.workflow_skill_refs["intent-to-infrastructure::compliance-check"], [])
      note             = "Spawn compliance-check-runner (deterministic compliance-check.sh). Mirror compliance_summary= compliance_blocked=; ≤8 lines. FORBIDDEN: read_notes, load_skill."
    },
    {
      stage_id         = "compliance-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["compliance-check"]
      action_config = {
        condition = "output_matches_regex"
        match     = "compliance_blocked=true|compliance_blocked:[^\\n]{0,20}true|compliance_summary=FAIL|compliance_summary:[^\\n]{0,20}FAIL"
        skip_to   = "final-intent-summary"
        reason    = "Contextual compliance hard-fail — skip synthesis and PR"
      }
    },
    {
      stage_id         = "synthesize-template"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["compliance-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.generate_template.name]
      skill_refs       = try(var.workflow_skill_refs["intent-to-infrastructure::synthesize-template"], try(var.workflow_skill_refs["intent-to-infrastructure::generate-template"], []))
      note             = "Catalog-aware synthesis; read WORK_ROOT/*.json only (not read_notes). Runbook embeds best-practices — FORBIDDEN load_skill. Write WORK_ROOT/generated/template.yaml; cap ${var.max_template_lines} lines."
    },
    {
      stage_id         = "quality-check"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["synthesize-template"]
      runbook_refs     = [sg_runbook_sop.validate_template.name, sg_runbook_sop.security_guardrails.name]
      skill_refs = concat(
        try(var.workflow_skill_refs["intent-to-infrastructure::quality-check"], []),
        try(var.workflow_skill_refs["intent-to-infrastructure::validate-template"], []),
        try(var.workflow_skill_refs["intent-to-infrastructure::security-guardrails-gate"], []),
      )
      spawn_contracts = local.spawn_contracts_intent_quality_check
      note            = "Spawn quality-check-runner once (lint + parallel guardrails); AWS validate-template when lint passes."
    },
    {
      stage_id         = "quality-rework-loop"
      action_type      = "loop_stage"
      stage_depends_on = ["quality-check"]
      action_config = {
        loop_to        = "synthesize-template"
        max_iterations = var.cfn_lint_max_iterations
        exit_condition = "output_contains"
        exit_match     = "cfn_lint_passed[^\\n]{0,20}true|security_guardrails_passed[^\\n]{0,20}true|module_quality_rework=false"
      }
    },
    {
      stage_id         = "quality-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["quality-rework-loop"]
      action_config = {
        condition = "output_matches_regex"
        match     = "cfn_lint_passed[^\\n]{0,20}false|security_guardrails_passed[^\\n]{0,20}false|security_guardrails_blocked:|policy_scan_passed[^\\n]{0,20}false|policy_scan_blocked:|validate_blocked=missing_generated_template|validate_blocked=missing_template"
        skip_to   = "final-intent-summary"
        reason    = "Quality checks failed after rework — skip PR"
      }
    },
    {
      stage_id         = "architecture-fit-review"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["quality-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.architecture_fit_review.name]
      spawn_contracts  = local.spawn_contracts_intent_architecture_fit
      skill_refs       = try(var.workflow_skill_refs["intent-to-infrastructure::architecture-fit-review"], [])
      note             = "Spawn architecture-fit-runner (deterministic architecture-lint.sh). Mirror architecture_summary=; ≤10 line output."
    },
    {
      stage_id         = "architecture-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["architecture-fit-review"]
      action_config = {
        condition = "output_matches_regex"
        match     = "architecture_summary=FAIL|architecture_blocked=true|architecture_lint_passed[^\\n]{0,20}false"
        skip_to   = "final-intent-summary"
        reason    = "Architecture lint critical failures — skip PR"
      }
    },
    {
      stage_id         = "open-pr"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["architecture-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.open_pr.name]
      skill_refs = concat(
        try(var.workflow_skill_refs["intent-to-infrastructure::open-pr"], []),
      )
      spawn_contracts = local.spawn_contracts_intent_open_pr
      note            = "Spawn open-pr-runner only. Mirror pr_url= tokens; stage output ≤5 lines. PR body is script-rendered (never PR_BODY from notes)."
    },
    {
      stage_id         = "publish-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["open-pr"]
      action_config = {
        condition = "output_matches_regex"
        match     = "governed_deployment_blocked:[^\\n]{0,20}true|clone_blocker=|pr_blocker=|pr_blocker[^\\n]{0,40}missing|stage_summary:open-pr=blocked|Open-PR Stage — Blocked|could not be spawned|not available in the tool registry|github-integration_execute_series"
        skip_to   = "final-intent-summary"
        reason    = "PR path blocked — skip change-set preview"
      }
    },
    {
      stage_id         = "preview-disabled-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["publish-blocked-gate"]
      action_config = {
        condition = "output_matches_regex"
        match     = local.preview_disabled_gate_match
        skip_to   = "final-intent-summary"
        reason    = "Change-set preview disabled in module configuration"
      }
    },
    {
      stage_id         = "preview-skip-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["preview-disabled-gate"]
      action_config = {
        condition = "output_matches_regex"
        match     = local.preview_skip_gate_match
        skip_to   = "final-intent-summary"
        reason    = "confirm_deploy not true — skip change-set preview"
      }
    },
    {
      stage_id         = "preview-safety-gate"
      action_type      = "policy_check"
      stage_depends_on = ["preview-skip-gate"]
      action_config = {
        inline_rego = local.change_set_safety_rego
      }
    },
    {
      stage_id         = "preview-changes"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["preview-safety-gate"]
      runbook_refs     = [sg_runbook_sop.preview_changes.name]
      skill_refs       = try(var.workflow_skill_refs["intent-to-infrastructure::preview-changes"], [])
      spawn_contracts  = local.spawn_contracts_intent_preview_changes
      note             = "Spawn preview-changes-runner (AWS change-set only). Never execute change sets."
    },
    {
      stage_id         = "final-intent-summary"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["intent-blocked-gate", "compliance-blocked-gate", "quality-blocked-gate", "architecture-blocked-gate", "publish-blocked-gate", "preview-disabled-gate", "preview-skip-gate", "preview-changes"]
      runbook_refs     = [sg_runbook_sop.final_intent_summary.name]
      spawn_contracts  = local.spawn_contracts_intent_final_summary
      skill_refs       = try(var.workflow_skill_refs["intent-to-infrastructure::final-intent-summary"], [])
      note             = "Spawn final-intent-summary-runner (script template from pr_url.txt + requirements_spec). FORBIDDEN LLM prose summary."
    },
  ]
}

resource "sg_workflow" "cloudformation_drift_management" {
  name        = local.workflow_drift_name
  domain      = "devops"
  description = trimspace(templatefile("${path.module}/templates/workflow-cloudformation-drift-management.md", local.template_vars))
  approve     = true

  evidence_checklist_ref = var.enable_evidence_checklist ? sg_evidence_checklist.drift_management[0].name : null

  metadata = {
    planner_max_tool_iterations       = "35"
    terminal_calling_halguard_mode    = "paste_only_minimal_planner"
    halguard_skip_subagent_task_types = "terminal_calling"
  }

  triggers = concat(
    [
      { field = "incident_title_contains", values = ["drift", "stack drift", "cloudformation drift", "drift audit", "reconcile drift"], type = "passive" },
    ],
    var.enable_drift_webhook ? [{ field = "source", values = ["webhook"], type = "active", source = "webhook" }] : [],
  )

  required_inputs = []
  optional_inputs = ["region", "stack_prefix", "environment", "stack_names", "workspace_id", "correlation_id", "drifted_stacks", "confirm_deploy"]

  runbook_refs = concat(
    [
      sg_runbook_sop.cfn_orchestration.name,
      sg_runbook_sop.parse_drift_scope.name,
      sg_runbook_sop.inventory_stacks.name,
      sg_runbook_sop.parallel_detect_drift.name,
      sg_runbook_sop.synthesize_drift_report.name,
      sg_runbook_sop.classify_drift_recommendation.name,
      sg_runbook_sop.reconcile_template_diff.name,
      sg_runbook_sop.open_reconcile_pr.name,
      sg_runbook_sop.final_drift_summary.name,
    ],
    [module.governance_runbooks.runbook_names.continuous_governance],
  )

  example_queries = [
    "Run drift management for stacks with prefix staging- in us-east-1 and open a reconcile PR if drift found",
    "Check CloudFormation drift across all prod stacks and recommend fixes for security risks",
    "Periodic drift scan: classify drift and incorporate valid changes via PR",
  ]

  stages = [
    { stage_id = "normalize-drift-ingress", description = "Normalize webhook or chat drift payload.", required = true },
    { stage_id = "parse-drift-scope", description = "Parse drift scan scope.", required = true },
    { stage_id = "scope-blocked-gate", description = "Skip when scope missing.", required = true },
    { stage_id = "inventory-stacks", description = "List stacks in scope.", required = true },
    { stage_id = "inventory-empty-gate", description = "Skip when no stacks.", required = true },
    { stage_id = "parallel-detect-drift", description = "Parallel batch drift detection.", required = true },
    { stage_id = "parallel-fan-in-gate", description = "Skip when parallel detect total failure.", required = true },
    { stage_id = "drift-retry-loop", description = "Retry throttled stacks.", required = true },
    { stage_id = "synthesize-drift-report", description = "Aggregate drift findings.", required = true },
    { stage_id = "classify-drift-recommendation", description = "FIX vs INCORPORATE vs IGNORE.", required = true },
    { stage_id = "no-drift-skip-gate", description = "Skip reconcile when clean.", required = true },
    { stage_id = "reconcile-template-diff", description = "Draft template updates for INCORPORATE.", required = true },
    { stage_id = "reconcile-pr-skip-gate", description = "Skip PR when disabled or no diffs.", required = true },
    { stage_id = "open-reconcile-pr", description = "Open reconcile PR.", required = true },
    { stage_id = "final-drift-summary", description = "Executive summary.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "normalize-drift-ingress"
      agent_ref    = sg_agent.cfn_drift_manager.name
      runbook_refs = [module.governance_runbooks.runbook_names.remote_orchestration, sg_runbook_sop.normalize_drift_ingress.name]
      skill_refs   = concat(["cfn-drift-scan-orchestration"], try(var.workflow_skill_refs["cloudformation-drift-management::normalize-drift-ingress"], []))
      note         = "Map drifted_stacks webhook JSON to stack_names/regions; note workspace_id and correlation_id."
    },
    {
      stage_id         = "parse-drift-scope"
      agent_ref        = sg_agent.cfn_drift_manager.name
      stage_depends_on = ["normalize-drift-ingress"]
      runbook_refs     = [sg_runbook_sop.parse_drift_scope.name, sg_runbook_sop.cfn_orchestration.name]
      skill_refs       = concat(["cfn-drift-scan-orchestration"], try(var.workflow_skill_refs["cloudformation-drift-management::parse-drift-scope"], []))
      note             = "Resolve regions, prefixes, environment filter; apply default workspace ${local.resolved_workspace.workspace_id}."
    },
    {
      stage_id         = "scope-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["parse-drift-scope"]
      action_config = {
        condition = "output_matches_regex"
        match     = "blocked:missing_drift_scope"
        skip_to   = "final-drift-summary"
        reason    = "Drift scope missing"
      }
    },
    {
      stage_id         = "inventory-stacks"
      agent_ref        = sg_agent.cfn_drift_manager.name
      stage_depends_on = ["scope-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.inventory_stacks.name]
      skill_refs       = concat(["cfn-drift-scan-orchestration"], try(var.workflow_skill_refs["cloudformation-drift-management::inventory-stacks"], []))
      note             = "List stacks; note stack_count."
    },
    {
      stage_id         = "inventory-empty-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["inventory-stacks"]
      action_config = {
        condition = "output_matches_regex"
        match     = "stack_count[^\\n]{0,20}0|stack_count=0|stacks_inventoried[^\\n]{0,40}stack_count.: 0"
        skip_to   = "final-drift-summary"
        reason    = "No stacks in scope"
      }
    },
    {
      stage_id         = "parallel-detect-drift"
      agent_ref        = sg_agent.cfn_drift_manager.name
      stage_depends_on = ["inventory-empty-gate"]
      runbook_refs     = [sg_runbook_sop.parallel_detect_drift.name]
      skill_refs       = concat(["cfn-drift-scan-orchestration"], try(var.workflow_skill_refs["cloudformation-drift-management::parallel-detect-drift"], []))
      spawn_contracts  = local.spawn_contracts_drift_batches
      note             = "When stack_count=0 or inventory-empty-gate skipped, emit drift_scan_complete=true without spawning batch runners. Otherwise ONE parallel fan-out: drift-detect-runner-batch-01..04."
    },
    {
      stage_id         = "parallel-fan-in-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["parallel-detect-drift"]
      action_config = {
        condition = "output_matches_regex"
        match     = "blocked:parallel_drift_failed"
        skip_to   = "final-drift-summary"
        reason    = "Parallel drift detection failed with zero partial results"
      }
    },
    {
      stage_id         = "drift-retry-loop"
      action_type      = "loop_stage"
      stage_depends_on = ["parallel-fan-in-gate"]
      action_config = {
        loop_to        = "parallel-detect-drift"
        max_iterations = var.drift_detection_max_retries
        exit_condition = "output_contains"
        exit_match     = "drift_scan_complete[^\\n]{0,20}true|drift_retry_exhausted:"
      }
    },
    {
      stage_id         = "synthesize-drift-report"
      agent_ref        = sg_agent.cfn_drift_manager.name
      stage_depends_on = ["drift-retry-loop"]
      runbook_refs     = [sg_runbook_sop.synthesize_drift_report.name, module.governance_runbooks.runbook_names.continuous_governance]
      skill_refs       = try(var.workflow_skill_refs["cloudformation-drift-management::synthesize-drift-report"], [])
      note             = "Aggregate drift_findings; drifted_stack_count; continuous governance report."
    },
    {
      stage_id         = "classify-drift-recommendation"
      agent_ref        = sg_agent.cfn_drift_manager.name
      stage_depends_on = ["synthesize-drift-report"]
      runbook_refs     = [sg_runbook_sop.classify_drift_recommendation.name, module.governance_runbooks.runbook_names.continuous_governance]
      skill_refs       = concat(["cfn-drift-risk-classifier"], try(var.workflow_skill_refs["cloudformation-drift-management::classify-drift-recommendation"], []))
      note             = "FIX_DRIFT vs INCORPORATE_VIA_PR vs IGNORE per resource."
    },
    {
      stage_id         = "no-drift-skip-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["classify-drift-recommendation"]
      action_config = {
        condition = "output_matches_regex"
        match     = "drifted_stack_count[^\\n]{0,20}0"
        skip_to   = "final-drift-summary"
        reason    = "No drift — skip reconcile PR"
      }
    },
    {
      stage_id         = "reconcile-template-diff"
      agent_ref        = sg_agent.cfn_drift_manager.name
      stage_depends_on = ["no-drift-skip-gate"]
      runbook_refs     = [sg_runbook_sop.reconcile_template_diff.name]
      skill_refs       = concat(["cfn-drift-incorporate-pr"], try(var.workflow_skill_refs["cloudformation-drift-management::reconcile-template-diff"], []))
      note             = "Draft template updates for INCORPORATE_VIA_PR items only."
    },
    {
      stage_id         = "reconcile-pr-skip-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["reconcile-template-diff"]
      action_config = {
        condition = "output_matches_regex"
        match     = var.enable_drift_remediation_pr ? "actionable_reconcile_diff[^\\n]{0,20}false|incorporate_count[^\\n]{0,20}0" : "incorporate_count"
        skip_to   = "final-drift-summary"
        reason    = "Reconcile PR disabled or no actionable diffs"
      }
    },
    {
      stage_id         = "open-reconcile-pr"
      agent_ref        = sg_agent.cfn_drift_manager.name
      stage_depends_on = ["reconcile-pr-skip-gate"]
      runbook_refs     = [sg_runbook_sop.open_reconcile_pr.name]
      skill_refs       = concat(["cfn-drift-incorporate-pr"], try(var.workflow_skill_refs["cloudformation-drift-management::open-reconcile-pr"], []))
      spawn_contracts  = local.spawn_contracts_drift_reconcile
      note             = "Spawn open-reconcile-pr-runner when INCORPORATE items exist."
    },
    {
      stage_id         = "final-drift-summary"
      agent_ref        = sg_agent.cfn_drift_manager.name
      stage_depends_on = ["open-reconcile-pr", "scope-blocked-gate", "inventory-empty-gate", "parallel-fan-in-gate", "no-drift-skip-gate", "reconcile-pr-skip-gate"]
      runbook_refs     = [sg_runbook_sop.final_drift_summary.name]
      skill_refs       = try(var.workflow_skill_refs["cloudformation-drift-management::final-drift-summary"], [])
      note             = "FIX_DRIFT recommendations + reconcile PR link + ignore count."
    },
  ]
}

# =============================================================================
# Webhook ingress — intent-to-infrastructure (remote trigger)
# =============================================================================

resource "sg_webhook" "intent_to_infrastructure" {
  count = var.enable_intent_webhook ? 1 : 0

  name          = local.webhook_intent_name
  target_type   = "workflow"
  target_name   = sg_workflow.intent_to_infrastructure.name
  action        = "A remote intent-to-infrastructure request was received. Parse the webhook JSON body for developer intent (intent, request, or description), optional stack_name, environment, workspace_id, and correlation_id, then generate a catalog-aligned CloudFormation template, validate, open a GitHub PR, and preview change set when stack_name is provided."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}

resource "sg_webhook" "drift_management" {
  count = var.enable_drift_webhook ? 1 : 0

  name          = local.webhook_drift_name
  target_type   = "workflow"
  target_name   = sg_workflow.cloudformation_drift_management.name
  action        = "A drift management webhook was received. Normalize drifted_stacks JSON (stack_name, region, environment), preserve workspace_id and correlation_id, then run drift detection and classification. Open reconcile PR only when enabled and drift is classified INCORPORATE_VIA_PR."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
