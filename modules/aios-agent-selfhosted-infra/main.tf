terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # sg_remote_runner (>= 0.1.23) when create_remote_runner; sg_webhook updates (>= 0.1.21).
      version = ">= 0.1.23, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "selfhosted-infra"
  suffix        = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_event_ingest_name    = "cfn-event-ingest${local.suffix}"
  agent_investigator_name    = "infra-investigator${local.suffix}"
  agent_change_engineer_name = "infra-change-engineer${local.suffix}"

  workflow_incident_name   = "cloudformation-stack-incident${local.suffix}"
  workflow_drift_name      = "cloudformation-drift-audit${local.suffix}"
  workflow_pre_deploy_name = "cloudformation-pre-deploy-review${local.suffix}"
  webhook_name             = "cloudformation-stack-failure${local.suffix}"

  sop_normalize_name    = "selfhosted-normalize-stack-event${local.suffix}"
  sop_stack_events_name = "selfhosted-analyze-stack-events${local.suffix}"
  sop_aws_corr_name     = "selfhosted-correlate-aws-resources${local.suffix}"
  sop_template_name     = "selfhosted-review-template${local.suffix}"
  sop_synthesize_name   = "selfhosted-synthesize-infra-rca${local.suffix}"
  sop_change_set_name   = "selfhosted-recommend-change-set${local.suffix}"
  sop_inventory_name    = "selfhosted-inventory-stacks${local.suffix}"
  sop_detect_drift_name = "selfhosted-detect-drift${local.suffix}"
  sop_report_drift_name = "selfhosted-report-drift${local.suffix}"
  sop_validate_name     = "selfhosted-validate-template-intent${local.suffix}"
  sop_policy_name       = "selfhosted-policy-sanity-check${local.suffix}"

  evidence_name = "selfhosted-infra-rca${local.suffix}"

  aws_integration_name    = "${local.module_prefix}-aws${local.suffix}"
  ubuntu_integration_name = "${local.module_prefix}-ubuntu${local.suffix}"

  provision_aws = (
    trimspace(var.aws_secret_id) != ""
    && trimspace(var.existing_aws_integration_name) == ""
  )

  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )

  create_ubuntu_integration = (
    var.enable_ubuntu_cli || var.create_remote_runner
  ) && trimspace(var.existing_ubuntu_integration_name) == ""

  resolved_ubuntu_integration_name = coalesce(
    trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : null,
    try(module.ubuntu_integration[0].integration_name, null),
    local.create_ubuntu_integration ? local.ubuntu_integration_name : null,
    "",
  )

  investigator_integrations = compact([
    local.resolved_aws_integration_name,
    local.resolved_ubuntu_integration_name != "" ? local.resolved_ubuntu_integration_name : null,
  ])

  change_engineer_integrations = compact([
    local.resolved_aws_integration_name,
    local.resolved_ubuntu_integration_name != "" ? local.resolved_ubuntu_integration_name : null,
  ])

  remote_runner_names = (
    var.create_remote_runner
    && var.remote_runner_attach_to_agent
    && length(module.remote_runner) > 0
  ) ? toset([module.remote_runner[0].runner_name]) : null

  prefixes_rego_literals            = join(", ", [for p in var.cloudformation_stack_prefix_allowlist : format("%q", lower(p))])
  environments_rego_literals        = join(", ", [for e in var.stack_ingest_allowed_environment_tags : format("%q", lower(e))])
  blocked_stack_names_rego_literals = join(", ", [for b in var.blocked_stack_names : format("%q", lower(b))])

  stack_ingest_filter_rego = trimspace(templatefile("${path.module}/templates/stack-ingest-filter.rego.tftpl", {
    prefixes_gate_enabled             = length(var.cloudformation_stack_prefix_allowlist) > 0
    prefixes_rego_literals            = local.prefixes_rego_literals
    environments_gate_enabled         = length(var.stack_ingest_allowed_environment_tags) > 0
    environments_rego_literals        = local.environments_rego_literals
    blocked_gate_enabled              = length(var.blocked_stack_names) > 0
    blocked_stack_names_rego_literals = local.blocked_stack_names_rego_literals
  }))

  template_vars = {
    self_hosted_environment_label = var.self_hosted_environment_label
    stack_tags_environment_key    = var.stack_tags_environment_key
    default_aws_regions           = jsonencode(var.default_aws_regions)
    cloudformation_stack_hints    = jsonencode(var.cloudformation_stack_hints)
  }

  attach_policy = {
    sre_remediation = try(var.policy_create_flags.sre_remediation, true)
    prod_write_gate = try(var.policy_create_flags.prod_write_gate, true)
  }
}

# =============================================================================
# Integration submodules
# =============================================================================

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
  description        = "AWS integration owned by ${local.agent_investigator_name} (self-hosted CloudFormation investigation)."
}

module "ubuntu_integration" {
  count  = local.create_ubuntu_integration ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = var.ubuntu_secret_ref_ids
  install_tools    = ["curl", "git", "jq", "python3-pip"]
  env_vars = {
    SELFHOSTED_ENABLE_CFN_LINT = "1"
  }
}

module "remote_runner" {
  count  = trimspace(var.remote_runner_name) != "" ? 1 : 0
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = trimspace(var.remote_runner_name)
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_investigator_name} (cfn-lint / shell in customer VPC)."
  labels        = var.remote_runner_labels
}

resource "terraform_data" "aws_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_aws_integration_name) != ""
      error_message = "aios-agent-selfhosted-infra needs an AWS Guild integration: provide `aws_secret_id` (the module provisions one) or `existing_aws_integration_name`."
    }
  }
}

resource "terraform_data" "remote_runner_name_required" {
  lifecycle {
    precondition {
      condition     = !var.create_remote_runner || trimspace(var.remote_runner_name) != ""
      error_message = "create_remote_runner requires a non-empty remote_runner_name."
    }
  }
}

# =============================================================================
# Agents
# =============================================================================

resource "sg_agent" "cfn_event_ingest" {
  name        = local.agent_event_ingest_name
  persona     = file("${path.module}/personas/cfn-event-ingest.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_aws_integration_name,
  ])
}

resource "sg_agent" "infra_investigator" {
  name        = local.agent_investigator_name
  persona     = file("${path.module}/personas/infra-investigator.md")
  model_names = compact(var.model_names)

  remote_runners = local.remote_runner_names

  integrations = local.investigator_integrations
}

resource "sg_agent" "infra_change_engineer" {
  name        = local.agent_change_engineer_name
  persona     = file("${path.module}/personas/infra-change-engineer.md")
  model_names = compact(var.model_names)

  remote_runners = local.remote_runner_names

  hitl = {
    always_allowed = compact([
      local.resolved_aws_integration_name != "" ? "${local.resolved_aws_integration_name}_test_connection" : "",
    ])
  }

  integrations = local.change_engineer_integrations
}

# =============================================================================
# Agent budgets
# =============================================================================

resource "sg_agent_budget" "cfn_event_ingest" {
  agent_name  = sg_agent.cfn_event_ingest.name
  limit_usd   = var.agent_budgets.event_ingest
  period_type = "daily"
}

resource "sg_agent_budget" "infra_investigator" {
  agent_name  = sg_agent.infra_investigator.name
  limit_usd   = var.agent_budgets.investigator
  period_type = "daily"
}

resource "sg_agent_budget" "infra_change_engineer" {
  agent_name  = sg_agent.infra_change_engineer.name
  limit_usd   = var.agent_budgets.change_engineer
  period_type = "daily"
}

# =============================================================================
# Policy attachments
# =============================================================================

resource "sg_agent_policy_attachment" "cfn_event_ingest_dangerous_ops" {
  agent_name = sg_agent.cfn_event_ingest.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "infra_investigator_dangerous_ops" {
  agent_name = sg_agent.infra_investigator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "infra_change_engineer_dangerous_ops" {
  agent_name = sg_agent.infra_change_engineer.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "infra_change_engineer_sre_remediation" {
  count      = local.attach_policy.sre_remediation ? 1 : 0
  agent_name = sg_agent.infra_change_engineer.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "infra_change_engineer_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate ? 1 : 0
  agent_name = sg_agent.infra_change_engineer.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

# =============================================================================
# Runbooks
# =============================================================================

resource "sg_runbook_sop" "normalize_stack_event" {
  name        = local.sop_normalize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-normalize-stack-event.md", local.template_vars))
}

resource "sg_runbook_sop" "analyze_stack_events" {
  name        = local.sop_stack_events_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-analyze-stack-events.md", local.template_vars))
}

resource "sg_runbook_sop" "correlate_aws_resources" {
  name        = local.sop_aws_corr_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-correlate-aws-resources.md", local.template_vars))
}

resource "sg_runbook_sop" "review_template" {
  name        = local.sop_template_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-review-template.md", local.template_vars))
}

resource "sg_runbook_sop" "synthesize_infra_rca" {
  name        = local.sop_synthesize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-synthesize-infra-rca.md", local.template_vars))
}

resource "sg_runbook_sop" "recommend_change_set" {
  name        = local.sop_change_set_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-recommend-change-set.md", local.template_vars))
}

resource "sg_runbook_sop" "inventory_stacks" {
  name        = local.sop_inventory_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-inventory-stacks.md", local.template_vars))
}

resource "sg_runbook_sop" "detect_drift" {
  name        = local.sop_detect_drift_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-detect-drift.md", local.template_vars))
}

resource "sg_runbook_sop" "report_drift" {
  name        = local.sop_report_drift_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-report-drift.md", local.template_vars))
}

resource "sg_runbook_sop" "validate_template_intent" {
  name        = local.sop_validate_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-validate-template-intent.md", local.template_vars))
}

resource "sg_runbook_sop" "policy_sanity_check" {
  name        = local.sop_policy_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-policy-sanity-check.md", local.template_vars))
}

# =============================================================================
# Evidence checklist
# =============================================================================

resource "sg_evidence_checklist" "selfhosted_infra_rca" {
  count       = var.enable_evidence_checklist ? 1 : 0
  name        = local.evidence_name
  description = "Proof-of-work for self-hosted infra RCA before change-set recommendation."
  approve     = true
  required_items = [
    "stack_events_analyzed",
    "aws_resources_correlated",
    "template_reviewed",
    "root_cause_stated",
    "change_set_documented",
  ]
  scoring = {
    min_required         = 4
    confidence_threshold = 0.70
  }
  metadata = { playbook = "cloudformation-stack-incident" }
}

# =============================================================================
# Workflow — CloudFormation stack incident
# =============================================================================

resource "sg_workflow" "cloudformation_stack_incident" {
  name        = local.workflow_incident_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-cloudformation-stack-incident.md", local.template_vars))
  approve     = true

  evidence_checklist_ref = var.enable_evidence_checklist ? sg_evidence_checklist.selfhosted_infra_rca[0].name : null

  metadata = {
    planner_max_tool_iterations = "40"
  }

  triggers = [
    { field = "source", values = ["cloudformation", "eventbridge", "sns"], type = "active", source = "cloudformation" },
    { field = "incident_title_contains", values = ["cloudformation", "stack", "rollback", "cfn"], type = "passive" },
  ]

  required_inputs = ["stack_name"]
  optional_inputs = ["region", "environment", "stack_status", "status_reason"]

  runbook_refs = [
    sg_runbook_sop.normalize_stack_event.name,
    sg_runbook_sop.analyze_stack_events.name,
    sg_runbook_sop.correlate_aws_resources.name,
    sg_runbook_sop.review_template.name,
    sg_runbook_sop.synthesize_infra_rca.name,
    sg_runbook_sop.recommend_change_set.name,
  ]

  example_queries = [
    "CloudFormation stack prod-vpc-network UPDATE_FAILED — investigate rollback and recommend change set",
    "Stack my-app-api CREATE_FAILED in us-east-1 — correlate AWS resource errors and review template",
    "EventBridge CFN failure for staging-data-store — full infra RCA with prod-safe change recommendation",
  ]

  stages = [
    { stage_id = "stack-ingest-filter", description = "Deterministic Rego filter on raw stack failure payload (prefix allowlist, blocked stacks, environment tag).", required = true },
    { stage_id = "normalize-stack-event", description = "Parse stack failure webhook or manual input; emit normalized_stack_event JSON.", required = true },
    { stage_id = "analyze-stack-events", description = "Identify failed resources and rollback reasons from stack events.", required = true },
    { stage_id = "correlate-aws-resources", description = "Inspect underlying AWS resource errors for failed logical resources.", required = true },
    { stage_id = "review-template", description = "Review template body, parameters, and policy issues.", required = true },
    { stage_id = "synthesize-infra-rca", description = "Cross-signal infra RCA synthesis.", required = true },
    { stage_id = "change-safety-gate", description = "Inline Rego blocks prod/production auto-changes.", required = true },
    { stage_id = "recommend-change-set", description = "Document change set recommendation; do not execute in prod without HITL.", required = true },
  ]

  stage_bindings = [
    {
      stage_id    = "stack-ingest-filter"
      action_type = "policy_check"
      action_config = {
        inline_rego = local.stack_ingest_filter_rego
      }
    },
    {
      stage_id         = "normalize-stack-event"
      agent_ref        = sg_agent.cfn_event_ingest.name
      stage_depends_on = ["stack-ingest-filter"]
      runbook_refs     = [sg_runbook_sop.normalize_stack_event.name]
      skill_refs       = concat(["selfhosted-normalize-stack-event"], try(var.workflow_skill_refs["cloudformation-stack-incident::normalize-stack-event"], []))
      note             = "Normalize inbound stack failure payload into stable incident envelope."
    },
    {
      stage_id         = "analyze-stack-events"
      agent_ref        = sg_agent.infra_investigator.name
      stage_depends_on = ["normalize-stack-event"]
      runbook_refs     = [sg_runbook_sop.analyze_stack_events.name]
      skill_refs       = concat(["selfhosted-analyze-stack-events"], try(var.workflow_skill_refs["cloudformation-stack-incident::analyze-stack-events"], []))
      note             = "Analyze CloudFormation stack events for failed resources and rollback reasons."
    },
    {
      stage_id         = "correlate-aws-resources"
      agent_ref        = sg_agent.infra_investigator.name
      stage_depends_on = ["analyze-stack-events"]
      runbook_refs     = [sg_runbook_sop.correlate_aws_resources.name]
      skill_refs       = concat(["selfhosted-correlate-aws-resources"], try(var.workflow_skill_refs["cloudformation-stack-incident::correlate-aws-resources"], []))
      note             = "Correlate failed logical resources with underlying AWS errors."
    },
    {
      stage_id         = "review-template"
      agent_ref        = sg_agent.infra_investigator.name
      stage_depends_on = ["correlate-aws-resources"]
      runbook_refs     = [sg_runbook_sop.review_template.name]
      skill_refs       = concat(["selfhosted-review-template"], try(var.workflow_skill_refs["cloudformation-stack-incident::review-template"], []))
      note             = "Review CloudFormation template body, parameters, and policy issues."
    },
    {
      stage_id         = "synthesize-infra-rca"
      agent_ref        = sg_agent.infra_investigator.name
      stage_depends_on = ["review-template"]
      runbook_refs     = [sg_runbook_sop.synthesize_infra_rca.name]
      skill_refs       = concat(["selfhosted-synthesize-infra-rca"], try(var.workflow_skill_refs["cloudformation-stack-incident::synthesize-infra-rca"], []))
      note             = "Synthesize self-hosted infrastructure RCA report."
    },
    {
      stage_id         = "change-safety-gate"
      action_type      = "policy_check"
      stage_depends_on = ["synthesize-infra-rca"]
      action_config = {
        inline_rego = <<-REGO
          package stage_gate

          import rego.v1

          default allow = true

          _text := lower(input.stage_input)

          # Block auto-changes when output reflects prod/production environment.
          allow = false if { is_prod_environment }

          is_prod_environment if { regex.match(`\bprod\b`, _text) }
          is_prod_environment if { contains(_text, "production") }
          is_prod_environment if { regex.match(`\benvironment["\s:=]+prod`, _text) }
          is_prod_environment if { regex.match(`\benvironment["\s:=]+production`, _text) }

          deny contains "Prod/production environment requires human-in-the-loop approval for auto-changes" if {
              is_prod_environment
          }
        REGO
      }
    },
    {
      stage_id         = "recommend-change-set"
      agent_ref        = sg_agent.infra_change_engineer.name
      stage_depends_on = ["change-safety-gate"]
      runbook_refs     = [sg_runbook_sop.recommend_change_set.name]
      skill_refs       = concat(["selfhosted-recommend-change-set"], try(var.workflow_skill_refs["cloudformation-stack-incident::recommend-change-set"], []))
      note             = "Document CloudFormation change set; do not execute in prod without HITL."
    },
  ]
}

# =============================================================================
# Workflow — CloudFormation drift audit (read-only)
# =============================================================================

resource "sg_workflow" "cloudformation_drift_audit" {
  name        = local.workflow_drift_name
  domain      = "devops"
  description = trimspace(templatefile("${path.module}/templates/workflow-cloudformation-drift-audit.md", local.template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "30"
  }

  triggers = [
    { field = "incident_title_contains", values = ["drift", "cloudformation", "stack audit"], type = "passive" },
  ]

  required_inputs = []
  optional_inputs = ["region", "environment"]

  runbook_refs = [
    sg_runbook_sop.inventory_stacks.name,
    sg_runbook_sop.detect_drift.name,
    sg_runbook_sop.report_drift.name,
  ]

  example_queries = [
    "Run CloudFormation drift audit across us-east-1 and us-west-2",
    "Report drift for prod stacks with environment tag production",
  ]

  stages = [
    { stage_id = "inventory-stacks", description = "List active and failed CloudFormation stacks per region.", required = true },
    { stage_id = "detect-drift", description = "Run drift detection and collect drifted resources.", required = true },
    { stage_id = "report-drift", description = "Summarize drift findings with remediation recommendations.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "inventory-stacks"
      agent_ref    = sg_agent.infra_investigator.name
      runbook_refs = [sg_runbook_sop.inventory_stacks.name]
      skill_refs   = concat(["selfhosted-inventory-stacks"], try(var.workflow_skill_refs["cloudformation-drift-audit::inventory-stacks"], []))
      note         = "Inventory CloudFormation stacks across configured regions."
    },
    {
      stage_id         = "detect-drift"
      agent_ref        = sg_agent.infra_investigator.name
      stage_depends_on = ["inventory-stacks"]
      runbook_refs     = [sg_runbook_sop.detect_drift.name]
      skill_refs       = concat(["selfhosted-detect-drift"], try(var.workflow_skill_refs["cloudformation-drift-audit::detect-drift"], []))
      note             = "Detect CloudFormation drift for inventoried stacks."
    },
    {
      stage_id         = "report-drift"
      agent_ref        = sg_agent.infra_investigator.name
      stage_depends_on = ["detect-drift"]
      runbook_refs     = [sg_runbook_sop.report_drift.name]
      skill_refs       = concat(["selfhosted-report-drift"], try(var.workflow_skill_refs["cloudformation-drift-audit::report-drift"], []))
      note             = "Report drift audit findings."
    },
  ]
}

# =============================================================================
# Workflow — CloudFormation pre-deploy review (read-only)
# =============================================================================

resource "sg_workflow" "cloudformation_pre_deploy_review" {
  name        = local.workflow_pre_deploy_name
  domain      = "devops"
  description = trimspace(templatefile("${path.module}/templates/workflow-cloudformation-pre-deploy-review.md", local.template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "25"
  }

  triggers = [
    { field = "incident_title_contains", values = ["pre-deploy", "template review", "cfn review"], type = "passive" },
  ]

  required_inputs = ["template_source"]
  optional_inputs = ["stack_name", "environment", "region"]

  runbook_refs = [
    sg_runbook_sop.validate_template_intent.name,
    sg_runbook_sop.policy_sanity_check.name,
  ]

  example_queries = [
    "Pre-deploy review for my-app-api CloudFormation template in staging",
    "Policy sanity check on S3 template before prod stack update",
  ]

  stages = [
    { stage_id = "validate-template-intent", description = "Validate template intent and deploy readiness.", required = true },
    { stage_id = "policy-sanity-check", description = "IAM, security group, and exposure policy review.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "validate-template-intent"
      agent_ref    = sg_agent.infra_investigator.name
      runbook_refs = [sg_runbook_sop.validate_template_intent.name]
      skill_refs   = concat(["selfhosted-validate-template-intent"], try(var.workflow_skill_refs["cloudformation-pre-deploy-review::validate-template-intent"], []))
      note         = "Validate CloudFormation template intent before deploy."
    },
    {
      stage_id         = "policy-sanity-check"
      agent_ref        = sg_agent.infra_investigator.name
      stage_depends_on = ["validate-template-intent"]
      runbook_refs     = [sg_runbook_sop.policy_sanity_check.name]
      skill_refs       = concat(["selfhosted-policy-sanity-check"], try(var.workflow_skill_refs["cloudformation-pre-deploy-review::policy-sanity-check"], []))
      note             = "Policy sanity check on CloudFormation template."
    },
  ]
}

# =============================================================================
# CloudFormation failure webhook ingress
# =============================================================================

resource "sg_webhook" "cloudformation_stack_failure" {
  count = var.enable_stack_failure_webhook ? 1 : 0

  name          = local.webhook_name
  target_type   = "workflow"
  target_name   = sg_workflow.cloudformation_stack_incident.name
  action        = "A CloudFormation stack failure occurred in the self-hosted environment. Parse the webhook JSON, apply ingest filters, investigate stack events and AWS resources, synthesize an infra RCA, and recommend a change set when allowed."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
