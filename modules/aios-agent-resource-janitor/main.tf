terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "resource-janitor"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name              = "resource-janitor${local.suffix}"
  workflow_detection_name = "unused-resource-detection${local.suffix}"
  workflow_cleanup_name   = "unused-resource-cleanup${local.suffix}"
  sop_lambda_name         = "lambda-inactivity-scan${local.suffix}"
  sop_s3_name             = "s3-stale-bucket-scan${local.suffix}"
  sop_compute_name        = "idle-compute-extended-scan${local.suffix}"
  sop_safe_cleanup_name   = "safe-cleanup-procedure${local.suffix}"
  evidence_cleanup_name   = "unused-resource-cleanup-evidence${local.suffix}"

  aws_integration_name   = "${local.module_prefix}-aws${local.suffix}"
  azure_integration_name = "${local.module_prefix}-azure${local.suffix}"
  gcp_integration_name   = "${local.module_prefix}-gcp${local.suffix}"
  slack_integration_name = "${local.module_prefix}-slack${local.suffix}"

  provision_aws   = trimspace(var.aws_secret_id) != "" && trimspace(var.existing_aws_integration_name) == ""
  provision_azure = trimspace(var.azure_secret_id) != "" && trimspace(var.existing_azure_integration_name) == ""
  provision_gcp   = trimspace(var.gcp_secret_id) != "" && trimspace(var.existing_gcp_integration_name) == ""
  provision_slack = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""

  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_azure_integration_name = trimspace(var.existing_azure_integration_name) != "" ? var.existing_azure_integration_name : (
    local.provision_azure ? module.azure_integration[0].integration_name : ""
  )
  resolved_gcp_integration_name = trimspace(var.existing_gcp_integration_name) != "" ? var.existing_gcp_integration_name : (
    local.provision_gcp ? module.gcp_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )

  _scan_surface_count = length(compact([local.resolved_aws_integration_name, local.resolved_azure_integration_name, local.resolved_gcp_integration_name]))
}

resource "terraform_data" "scan_surface_required" {
  lifecycle {
    precondition {
      condition     = local._scan_surface_count > 0
      error_message = "aios-agent-resource-janitor needs at least one cloud surface: provide aws_secret_id, azure_secret_id, or gcp_secret_id (or one of the existing_*_integration_name overrides)."
    }
  }
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
}

module "azure_integration" {
  count  = local.provision_azure ? 1 : 0
  source = "../aios-integration-azure"

  integration_name   = local.azure_integration_name
  existing_secret_id = var.azure_secret_id
}

module "gcp_integration" {
  count  = local.provision_gcp ? 1 : 0
  source = "../aios-integration-gcp"

  integration_name   = local.gcp_integration_name
  existing_secret_id = var.gcp_secret_id
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

# =============================================================================
# Multi-Cloud Unused Resource Janitor — agent + runbooks + workflows
# =============================================================================

resource "sg_agent" "resource_janitor" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/resource-janitor.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }

  integrations = compact([
    local.resolved_aws_integration_name,
    local.resolved_azure_integration_name,
    local.resolved_gcp_integration_name,
    local.resolved_slack_integration_name,
  ])
}

resource "sg_agent_budget" "resource_janitor" {
  agent_name  = sg_agent.resource_janitor.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.resource_janitor.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# -----------------------------------------------------------------------------
# Runbooks
# -----------------------------------------------------------------------------

resource "sg_runbook_sop" "lambda_inactivity_scan" {
  name    = local.sop_lambda_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/lambda-inactivity-scan.md", {
    inactivity_days = var.inactivity_days
  }))
}

resource "sg_runbook_sop" "s3_stale_bucket_scan" {
  name    = local.sop_s3_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/s3-stale-bucket-scan.md", {
    inactivity_days = var.inactivity_days
  }))
}

resource "sg_runbook_sop" "idle_compute_extended_scan" {
  name    = local.sop_compute_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/idle-compute-extended-scan.md", {
    inactivity_days = var.inactivity_days
  }))
}

resource "sg_runbook_sop" "safe_cleanup_procedure" {
  name        = local.sop_safe_cleanup_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/safe-cleanup-procedure.md", {}))
}

# -----------------------------------------------------------------------------
# Evidence checklist for the destructive cleanup workflow
# -----------------------------------------------------------------------------

resource "sg_evidence_checklist" "unused_resource_cleanup_evidence" {
  name        = local.evidence_cleanup_name
  description = "Proof-of-work for destructive cleanup runs: detection batch, owner notification, quarantine tags, and operator approval before deletion."
  approve     = true
  required_items = [
    "detection_batch_id_referenced",
    "owner_notification_sent",
    "quarantine_tags_applied",
    "operator_approval_recorded",
  ]
  optional_items = [
    "estimated_savings_realized_usd",
    "rollback_path_documented",
  ]
  scoring = {
    min_required         = 3
    confidence_threshold = 0.75
  }
  metadata = { playbook = "unused-resource-cleanup" }
}

# -----------------------------------------------------------------------------
# Detection workflow (read-only) — schedule weekly via aios-agent-schedules
# -----------------------------------------------------------------------------

resource "sg_workflow" "unused_resource_detection" {
  name        = local.workflow_detection_name
  domain      = "finops"
  description = trimspace(templatefile("${path.module}/templates/workflow-unused-resource-detection.md", {}))
  approve     = true

  required_inputs = []
  optional_inputs = ["inactivity_days", "team_filter", "region_filter"]

  example_queries = [
    "Find Lambdas that have not been invoked in the last 30 days",
    "Which S3 buckets have not been written to in over a month?",
    "Show me unattached EBS volumes with their owners",
    "Run the weekly unused resource sweep and post by team to Slack",
  ]

  stages = [
    { stage_id = "scan-lambda", description = "Scan Lambda functions for inactivity over the configured window.", required = true },
    { stage_id = "scan-s3", description = "Scan S3 buckets for stale-write activity.", required = true },
    { stage_id = "scan-compute", description = "Scan extended idle compute and storage across AWS, Azure, and GCP.", required = true },
    { stage_id = "summarize-findings", description = "Group findings by owner / cost-center; emit a per-team summary.", required = true },
    { stage_id = "notify", description = "Post the per-team summary to Slack (when integration is attached).", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "scan-lambda"
      agent_ref    = sg_agent.resource_janitor.name
      runbook_refs = [sg_runbook_sop.lambda_inactivity_scan.name]
      skill_refs   = concat(["finops-lambda-inactivity"], try(var.workflow_skill_refs["unused-resource-detection::scan-lambda"], []))
    },
    {
      stage_id     = "scan-s3"
      agent_ref    = sg_agent.resource_janitor.name
      runbook_refs = [sg_runbook_sop.s3_stale_bucket_scan.name]
      skill_refs   = concat(["finops-s3-stale-bucket"], try(var.workflow_skill_refs["unused-resource-detection::scan-s3"], []))
    },
    {
      stage_id     = "scan-compute"
      agent_ref    = sg_agent.resource_janitor.name
      runbook_refs = [sg_runbook_sop.idle_compute_extended_scan.name]
      skill_refs   = concat(["finops-idle-compute-extended"], try(var.workflow_skill_refs["unused-resource-detection::scan-compute"], []))
    },
    {
      stage_id         = "summarize-findings"
      agent_ref        = sg_agent.resource_janitor.name
      stage_depends_on = ["scan-lambda", "scan-s3", "scan-compute"]
      skill_refs       = concat(["finops-owner-grouped-summary"], try(var.workflow_skill_refs["unused-resource-detection::summarize-findings"], []))
    },
    {
      stage_id         = "notify"
      agent_ref        = sg_agent.resource_janitor.name
      stage_depends_on = ["summarize-findings"]
      skill_refs       = concat(["finops-slack-team-notification"], try(var.workflow_skill_refs["unused-resource-detection::notify"], []))
    },
  ]
}

# -----------------------------------------------------------------------------
# Cleanup workflow (HITL-gated, destructive) — operators trigger explicitly
# -----------------------------------------------------------------------------

resource "sg_workflow" "unused_resource_cleanup" {
  name                   = local.workflow_cleanup_name
  domain                 = "finops"
  description            = trimspace(templatefile("${path.module}/templates/workflow-unused-resource-cleanup.md", {}))
  approve                = true
  evidence_checklist_ref = sg_evidence_checklist.unused_resource_cleanup_evidence.name

  required_inputs = ["detection_run_id"]
  optional_inputs = ["max_resources", "dollar_cap", "team_filter", "force_phase"]

  runbook_refs = [
    sg_runbook_sop.safe_cleanup_procedure.name,
  ]

  example_queries = [
    "Quarantine the unused resources from yesterday's detection run for the payments team",
    "Delete the resources that finished their quarantine dwell period this morning",
    "Run cleanup phase 1 for run-id 2026-05-13-detect, capped at 10 resources",
  ]

  stages = [
    { stage_id = "load-detection-batch", description = "Load the referenced detection run and re-validate freshness (≤ 7 days).", required = true },
    { stage_id = "preflight-gate", description = "Drop resources missing owner tags, exempt-tagged, or referenced by active workloads.", required = true },
    { stage_id = "quarantine", description = "Tag and quarantine eligible resources; notify owners. Bounded by max_resources_per_run + cleanup_dollar_cap.", required = true },
    { stage_id = "delete", description = "After dwell window, delete previously quarantined resources via dangerous-ops with operator approval.", required = true },
    { stage_id = "report", description = "Post final cleanup summary (resources, owners, savings realized) to Slack.", required = true },
  ]

  stage_bindings = [
    {
      stage_id   = "load-detection-batch"
      agent_ref  = sg_agent.resource_janitor.name
      skill_refs = concat(["finops-cleanup-load-batch"], try(var.workflow_skill_refs["unused-resource-cleanup::load-detection-batch"], []))
    },
    {
      stage_id         = "preflight-gate"
      agent_ref        = sg_agent.resource_janitor.name
      stage_depends_on = ["load-detection-batch"]
      runbook_refs     = [sg_runbook_sop.safe_cleanup_procedure.name]
      skill_refs       = concat(["finops-cleanup-preflight"], try(var.workflow_skill_refs["unused-resource-cleanup::preflight-gate"], []))
    },
    {
      stage_id         = "quarantine"
      agent_ref        = sg_agent.resource_janitor.name
      stage_depends_on = ["preflight-gate"]
      runbook_refs     = [sg_runbook_sop.safe_cleanup_procedure.name]
      note             = format("Cap %d resources per run; stop early when accumulated estimated savings exceed $%d.", var.max_resources_per_run, var.cleanup_dollar_cap)
      skill_refs       = concat(["finops-cleanup-quarantine"], try(var.workflow_skill_refs["unused-resource-cleanup::quarantine"], []))
    },
    {
      stage_id         = "delete"
      agent_ref        = sg_agent.resource_janitor.name
      stage_depends_on = ["quarantine"]
      runbook_refs     = [sg_runbook_sop.safe_cleanup_procedure.name]
      note             = format("Only delete resources whose `aios:cleanup:scheduled-deletion` date has passed (dwell %d days). Requires HITL approval via dangerous-ops.", var.cleanup_dwell_days)
      skill_refs       = concat(["finops-cleanup-delete"], try(var.workflow_skill_refs["unused-resource-cleanup::delete"], []))
    },
    {
      stage_id         = "report"
      agent_ref        = sg_agent.resource_janitor.name
      stage_depends_on = ["delete"]
      skill_refs       = concat(["finops-cleanup-report"], try(var.workflow_skill_refs["unused-resource-cleanup::report"], []))
    },
  ]
}
