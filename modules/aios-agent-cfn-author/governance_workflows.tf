# =============================================================================
# Governance pillar workflows (contextual compliance, governed deployment)
# =============================================================================

resource "sg_workflow" "contextual_compliance" {
  count = var.enable_contextual_compliance_workflow ? 1 : 0

  name        = local.workflow_compliance_name
  domain      = "platform-engineering"
  description = trimspace(templatefile("${path.module}/templates/workflow-cfn-contextual-compliance.md", local.template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "25"
  }

  triggers = concat(
    [
      { field = "incident_title_contains", values = ["fedramp", "compliance check", "baseline check", "contextual compliance"], type = "passive" },
    ],
    var.enable_compliance_webhook ? [{ field = "source", values = ["webhook"], type = "active", source = "webhook" }] : [],
  )

  required_inputs = []
  optional_inputs = ["intent", "request", "description", "environment", "template_path", "ci_pipeline", "correlation_id", "workspace_id", "confirm_deploy"]

  runbook_refs = [
    sg_runbook_sop.parse_requirements.name,
    module.governance_runbooks.runbook_names.remote_orchestration,
    module.governance_runbooks.runbook_names.contextual_compliance,
  ]

  example_queries = [
    "Preflight this intent against FedRAMP moderate and our org baseline: private RDS in us-east-1",
    "Contextual compliance check for S3 bucket with public access in production",
    "CI compliance gate: validate webhook intent before synthesis",
  ]

  stages = [
    { stage_id = "parse-compliance-intent", description = "Parse compliance review scope.", required = true },
    { stage_id = "compliance-intent-blocked-gate", description = "Skip when intent missing.", required = true },
    { stage_id = "normalize-remote-orchestration", description = "Normalize API/CI payload.", required = true },
    { stage_id = "contextual-compliance-check", description = "FedRAMP and baseline findings.", required = true },
    { stage_id = "final-compliance-summary", description = "Compliance report for caller.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "parse-compliance-intent"
      agent_ref    = sg_agent.cfn_author.name
      runbook_refs = [sg_runbook_sop.parse_requirements.name]
      skill_refs   = concat(["cfn-developer-intent-handler"], try(var.workflow_skill_refs["cfn-contextual-compliance::parse-compliance-intent"], []))
      note         = "Parse intent or webhook JSON for compliance preflight scope."
    },
    {
      stage_id         = "compliance-intent-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["parse-compliance-intent"]
      action_config = {
        condition = "output_matches_regex"
        match     = "blocked:missing_intent|blocked:missing_description|blocked:missing_request|blocked:missing_template"
        skip_to   = "final-compliance-summary"
        reason    = "Compliance intent missing"
      }
    },
    {
      stage_id         = "normalize-remote-orchestration"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["compliance-intent-blocked-gate"]
      runbook_refs     = [module.governance_runbooks.runbook_names.remote_orchestration]
      skill_refs       = try(var.workflow_skill_refs["cfn-contextual-compliance::normalize-remote-orchestration"], [])
      note             = "Normalize CI/CD or API payload; preserve correlation_id."
    },
    {
      stage_id         = "contextual-compliance-check"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["normalize-remote-orchestration"]
      runbook_refs     = [module.governance_runbooks.runbook_names.contextual_compliance]
      skill_refs       = try(var.workflow_skill_refs["cfn-contextual-compliance::contextual-compliance-check"], [])
      note             = "Emit compliance_report with fedramp_findings and baseline_findings."
    },
    {
      stage_id         = "final-compliance-summary"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["contextual-compliance-check", "compliance-intent-blocked-gate"]
      runbook_refs     = [module.governance_runbooks.runbook_names.contextual_compliance]
      skill_refs       = try(var.workflow_skill_refs["cfn-contextual-compliance::final-compliance-summary"], [])
      note             = "Plain-English compliance summary for CI/CD or chat caller."
    },
  ]
}

resource "sg_workflow" "governed_deployment" {
  count = var.enable_governed_deployment_workflow ? 1 : 0

  name        = local.workflow_governed_name
  domain      = "platform-engineering"
  description = trimspace(templatefile("${path.module}/templates/workflow-cfn-governed-deployment.md", local.template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "30"
  }

  triggers = [
    { field = "incident_title_contains", values = ["governed deployment", "open cfn pr", "governed pr", "deployment gate"], type = "passive" },
  ]

  required_inputs = []
  optional_inputs = ["template_file_name", "stack_name", "environment", "pr_title", "pr_body"]

  runbook_refs = [
    sg_runbook_sop.open_pr.name,
    module.governance_runbooks.runbook_names.governed_deployment,
  ]

  example_queries = [
    "Open a governed PR for validated template cloudformation/staging-vpc.yaml",
    "Governed deployment: template passed lint — open PR with compliance summary",
  ]

  stages = [
    { stage_id = "parse-governed-context", description = "Parse governed PR context.", required = true },
    { stage_id = "governed-context-blocked-gate", description = "Skip when context missing.", required = true },
    { stage_id = "governed-deployment-gate", description = "Org deployment process check.", required = true },
    { stage_id = "governed-deployment-blocked-gate", description = "Skip PR when blocked.", required = true },
    { stage_id = "open-pr", description = "Open GitHub PR.", required = true },
    { stage_id = "final-governed-summary", description = "PR and process summary.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "parse-governed-context"
      agent_ref    = sg_agent.cfn_author.name
      runbook_refs = [sg_runbook_sop.parse_requirements.name]
      skill_refs   = try(var.workflow_skill_refs["cfn-governed-deployment::parse-governed-context"], [])
      note         = "Confirm template path, validation status notes, and PR metadata."
    },
    {
      stage_id         = "governed-context-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["parse-governed-context"]
      action_config = {
        condition = "output_matches_regex"
        match     = "blocked:missing_template|blocked:missing_template_path|blocked:missing_intent"
        skip_to   = "final-governed-summary"
        reason    = "Governed deployment context incomplete"
      }
    },
    {
      stage_id         = "governed-deployment-gate"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["governed-context-blocked-gate"]
      runbook_refs     = [module.governance_runbooks.runbook_names.governed_deployment]
      skill_refs       = try(var.workflow_skill_refs["cfn-governed-deployment::governed-deployment-gate"], [])
      note             = "Verify org PR review, change window, and preview requirements."
    },
    {
      stage_id         = "governed-deployment-blocked-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["governed-deployment-gate"]
      action_config = {
        condition = "output_matches_regex"
        match     = "governed_deployment_blocked:[^\\n]{0,20}true"
        skip_to   = "final-governed-summary"
        reason    = "Governed deployment prerequisites not met"
      }
    },
    {
      stage_id         = "open-pr"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["governed-deployment-blocked-gate"]
      runbook_refs     = [sg_runbook_sop.open_pr.name, module.governance_runbooks.runbook_names.governed_deployment]
      skill_refs       = try(var.workflow_skill_refs["cfn-governed-deployment::open-pr"], [])
      spawn_contracts  = local.spawn_contracts_intent_open_pr
      note             = "Spawn open-pr-runner with governed PR title/body."
    },
    {
      stage_id         = "final-governed-summary"
      agent_ref        = sg_agent.cfn_author.name
      stage_depends_on = ["open-pr", "governed-context-blocked-gate", "governed-deployment-blocked-gate"]
      runbook_refs     = [module.governance_runbooks.runbook_names.governed_deployment]
      skill_refs       = try(var.workflow_skill_refs["cfn-governed-deployment::final-governed-summary"], [])
      note             = "PR URL, deployment process checklist, and blockers."
    },
  ]
}

resource "sg_webhook" "contextual_compliance" {
  count = var.enable_contextual_compliance_workflow && var.enable_compliance_webhook ? 1 : 0

  name          = local.webhook_compliance_name
  target_type   = "workflow"
  target_name   = sg_workflow.contextual_compliance[0].name
  action        = "A contextual compliance preflight request was received. Parse webhook JSON for infrastructure intent, normalize remote orchestration fields, and evaluate against FedRAMP and organisational baseline. Return compliance_report — do not synthesize templates or open PRs."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
