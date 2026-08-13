terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "cicd-overwatch"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name    = "cicd-overwatch-investigator${local.suffix}"
  workflow_name = "cicd-overwatch-jenkins-rca${local.suffix}"
  webhook_name  = "cicd-overwatch-linear-ticket-receiver${local.suffix}"

  knowledge_base_name = "cicd-overwatch-jenkins-rca-kb${local.suffix}"

  sop_claim     = "cicd-overwatch-claim-ticket${local.suffix}"
  sop_context   = "cicd-overwatch-read-ticket-context${local.suffix}"
  sop_evidence  = "cicd-overwatch-collect-live-evidence${local.suffix}"
  sop_diagnose  = "cicd-overwatch-diagnose-and-recommend${local.suffix}"
  sop_post_rca  = "cicd-overwatch-post-linear-rca${local.suffix}"
  sop_remediate = "cicd-overwatch-approved-remediation${local.suffix}"

  jenkins_integration_name = "${local.module_prefix}-jenkins${local.suffix}"
  linear_integration_name  = "${local.module_prefix}-linear${local.suffix}"
  aws_integration_name     = "${local.module_prefix}-aws${local.suffix}"
  github_integration_name  = "${local.module_prefix}-github${local.suffix}"

  provision_jenkins = (
    (trimspace(var.jenkins_base_url) != "" || trimspace(var.jenkins_secret_id) != "")
    && trimspace(var.existing_jenkins_integration_name) == ""
  )
  provision_linear = (
    (trimspace(var.linear_api_key) != "" || trimspace(var.linear_credential_provider_id) != "" || trimspace(var.linear_secret_id) != "")
    && trimspace(var.existing_linear_integration_name) == ""
  )
  provision_aws = (
    (trimspace(var.aws_role_arn) != "" || trimspace(var.aws_secret_id) != "")
    && trimspace(var.existing_aws_integration_name) == ""
  )
  provision_github = (
    (trimspace(var.github_token) != "" || trimspace(var.github_secret_id) != "")
    && trimspace(var.existing_github_integration_name) == ""
  )

  resolved_jenkins_integration_name = trimspace(var.existing_jenkins_integration_name) != "" ? var.existing_jenkins_integration_name : (
    local.provision_jenkins ? module.jenkins_integration[0].integration_name : ""
  )
  resolved_linear_integration_name = trimspace(var.existing_linear_integration_name) != "" ? var.existing_linear_integration_name : (
    local.provision_linear ? module.linear_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )

  attach_policy = {
    dangerous_ops   = try(var.policy_create_flags.dangerous_ops, true)
    prod_write_gate = try(var.policy_create_flags.prod_write_gate, true)
  }

  knowledge_raw_base = "https://raw.githubusercontent.com/${var.knowledge_source_repo}/${var.knowledge_source_ref}/modules/aios-agent-cicd-overwatch-jenkins-rca/knowledge"

  knowledge_documents = {
    incident_investigation_sop        = "incident-investigation-sop.md"
    jenkins_topology                  = "jenkins-topology.md"
    aws_artifact_investigation        = "aws-artifact-investigation.md"
    source_and_contract_investigation = "source-and-contract-investigation.md"
    safe_remediation                  = "safe-remediation.md"
  }
}

# =============================================================================
# Integration submodules (optional — omit when existing_*_integration_name is set)
# =============================================================================

module "jenkins_integration" {
  count  = local.provision_jenkins ? 1 : 0
  source = "../aios-integration-jenkins"

  integration_name   = local.jenkins_integration_name
  jenkins_base_url   = var.jenkins_base_url
  jenkins_username   = var.jenkins_username
  jenkins_token      = var.jenkins_token
  existing_secret_id = var.jenkins_secret_id
  description        = "Jenkins integration owned by ${local.agent_name} (CICD Overwatch RCA)."
}

module "linear_integration" {
  count  = local.provision_linear ? 1 : 0
  source = "../aios-integration-linear"

  integration_name       = local.linear_integration_name
  linear_api_key         = var.linear_api_key
  credential_provider_id = var.linear_credential_provider_id
  existing_secret_id     = var.linear_secret_id
  description            = "Linear integration owned by ${local.agent_name} (CICD Overwatch RCA)."
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  aws_role_arn       = var.aws_role_arn
  aws_region         = var.aws_region
  existing_secret_id = var.aws_secret_id
  description        = "AWS integration owned by ${local.agent_name} (CICD Overwatch artifact/deployment evidence)."
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  github_token       = var.github_token
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by ${local.agent_name} (CICD Overwatch source/contract evidence)."
}

resource "terraform_data" "jenkins_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_jenkins_integration_name) != ""
      error_message = "aios-agent-cicd-overwatch-jenkins-rca needs a Jenkins Guild integration: provide inline credentials, `jenkins_secret_id`, or `existing_jenkins_integration_name`."
    }
  }
}

resource "terraform_data" "linear_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_linear_integration_name) != ""
      error_message = "aios-agent-cicd-overwatch-jenkins-rca needs a Linear Guild integration: provide inline credentials, `linear_secret_id`, or `existing_linear_integration_name`."
    }
  }
}

# =============================================================================
# Agent (single persona used across all six workflow stages)
# =============================================================================

resource "sg_agent" "investigator" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/cicd-overwatch-investigator.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_jenkins_integration_name,
    local.resolved_linear_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_github_integration_name,
  ])

  knowledge = {
    memory_enabled = true
  }

  # Read-only / comment tools may bypass HITL; anything mutating (Jenkins reruns/restarts,
  # AWS changes, GitHub changes) always requires human approval — see optional-approved-remediation.
  hitl = {
    always_allowed = compact([
      local.resolved_linear_integration_name != "" ? "${local.resolved_linear_integration_name}_comment" : "",
      local.resolved_linear_integration_name != "" ? "${local.resolved_linear_integration_name}_update_issue" : "",
      local.resolved_jenkins_integration_name != "" ? "${local.resolved_jenkins_integration_name}_get_build" : "",
      local.resolved_jenkins_integration_name != "" ? "${local.resolved_jenkins_integration_name}_get_console_log" : "",
    ])
  }
}

resource "sg_agent_budget" "investigator" {
  agent_name  = sg_agent.investigator.name
  limit_usd   = var.agent_budget_usd
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "investigator_dangerous_ops" {
  count      = local.attach_policy.dangerous_ops && trimspace(var.policy_ids.dangerous_ops) != "" ? 1 : 0
  agent_name = sg_agent.investigator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "investigator_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate && trimspace(var.policy_ids.prod_write_gate) != "" ? 1 : 0
  agent_name = sg_agent.investigator.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

# =============================================================================
# Skills (manually created Guild skills from skills/*.md — one per stage)
# =============================================================================

resource "sg_skill" "cicd_overwatch" {
  for_each = fileset("${path.module}/skills", "*.md")

  skill_md = file("${path.module}/skills/${each.value}")
}

# =============================================================================
# Optional knowledge base — uploads the bundled CICD Overwatch reference docs
# =============================================================================

resource "sg_knowledge_base" "cicd_overwatch" {
  count = var.enable_knowledge_base ? 1 : 0

  name        = local.knowledge_base_name
  description = "CICD Overwatch Jenkins/Linear incident investigation SOP, topology, and safe-remediation reference documents."
}

resource "sg_knowledge_document" "cicd_overwatch" {
  for_each = var.enable_knowledge_base ? local.knowledge_documents : {}

  knowledge_base_id = sg_knowledge_base.cicd_overwatch[0].id
  knowledge_type    = "KNOWLEDGE"
  source_url        = "${local.knowledge_raw_base}/${each.value}"
}

# =============================================================================
# Runbooks (one per stage)
# =============================================================================

resource "sg_runbook_sop" "claim_ticket" {
  name        = local.sop_claim
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-claim-ticket.md"))
}

resource "sg_runbook_sop" "read_ticket_context" {
  name        = local.sop_context
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-read-ticket-context.md"))
}

resource "sg_runbook_sop" "collect_live_evidence" {
  name        = local.sop_evidence
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-collect-live-evidence.md"))
}

resource "sg_runbook_sop" "diagnose_and_recommend" {
  name        = local.sop_diagnose
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-diagnose-and-recommend.md"))
}

resource "sg_runbook_sop" "post_linear_rca" {
  name        = local.sop_post_rca
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-post-linear-rca.md"))
}

resource "sg_runbook_sop" "approved_remediation" {
  name        = local.sop_remediate
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-approved-remediation.md"))
}

# =============================================================================
# Workflow — CICD Overwatch Jenkins RCA (6 stages, single agent)
# =============================================================================

resource "sg_workflow" "cicd_overwatch_jenkins_rca" {
  name        = local.workflow_name
  domain      = "incident-response"
  description = trimspace(file("${path.module}/templates/workflow-cicd-overwatch-jenkins-rca.md"))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "40"
  }

  triggers = [
    { field = "source", values = ["linear"], type = "active", source = "linear" },
    { field = "ticket_labels_contains", values = ["incident", "help-needed"], type = "passive" },
  ]

  required_inputs = ["linear_issue_id"]
  optional_inputs = ["linear_issue_title", "linear_issue_body", "linear_labels", "jenkins_job", "jenkins_build_number"]

  runbook_refs = [
    sg_runbook_sop.claim_ticket.name,
    sg_runbook_sop.read_ticket_context.name,
    sg_runbook_sop.collect_live_evidence.name,
    sg_runbook_sop.diagnose_and_recommend.name,
    sg_runbook_sop.post_linear_rca.name,
    sg_runbook_sop.approved_remediation.name,
  ]

  example_queries = [
    "Linear CICD-102 — Jenkins release pipeline failed, investigate and post RCA",
    "Investigate 00-release-pipeline build #58 referenced in this Linear ticket and recommend a fix",
    "Approved: rerun 04-build-push-image-ecr-scan after the registry credential fix",
  ]

  stages = [
    { stage_id = "claim-ticket-in-progress", description = "Assign and move the Linear ticket to in-progress.", required = true },
    { stage_id = "read-ticket-context", description = "Parse the ticket and extract concrete identifiers.", required = true },
    { stage_id = "collect-live-evidence", description = "Query Jenkins (and AWS/GitHub when attached) for build and artifact/source evidence.", required = true },
    { stage_id = "diagnose-and-recommend", description = "Classify the failure class and recommend the smallest safe fix.", required = true },
    { stage_id = "post-linear-rca", description = "Post a concise RCA comment to the Linear ticket.", required = true },
    { stage_id = "optional-approved-remediation", description = "Execute an operator-approved fix and report back; skipped when no approval exists.", required = false },
  ]

  stage_bindings = [
    {
      stage_id     = "claim-ticket-in-progress"
      agent_ref    = sg_agent.investigator.name
      runbook_refs = [sg_runbook_sop.claim_ticket.name]
      skill_refs   = concat(["cicd-overwatch-ticket-claim"], try(var.workflow_skill_refs["cicd-overwatch-jenkins-rca::claim-ticket-in-progress"], []))
      note         = "Claim the ticket and move it to in-progress before investigating."
    },
    {
      stage_id         = "read-ticket-context"
      agent_ref        = sg_agent.investigator.name
      stage_depends_on = ["claim-ticket-in-progress"]
      runbook_refs     = [sg_runbook_sop.read_ticket_context.name]
      skill_refs       = concat(["cicd-overwatch-ticket-context"], try(var.workflow_skill_refs["cicd-overwatch-jenkins-rca::read-ticket-context"], []))
      note             = "Extract concrete identifiers from the ticket before touching Jenkins."
    },
    {
      stage_id         = "collect-live-evidence"
      agent_ref        = sg_agent.investigator.name
      stage_depends_on = ["read-ticket-context"]
      runbook_refs     = [sg_runbook_sop.collect_live_evidence.name]
      skill_refs       = concat(["cicd-overwatch-jenkins-evidence"], try(var.workflow_skill_refs["cicd-overwatch-jenkins-rca::collect-live-evidence"], []))
      note             = "Collect live Jenkins evidence, extending into AWS/GitHub when attached."
    },
    {
      stage_id         = "diagnose-and-recommend"
      agent_ref        = sg_agent.investigator.name
      stage_depends_on = ["collect-live-evidence"]
      runbook_refs     = [sg_runbook_sop.diagnose_and_recommend.name]
      skill_refs       = concat(["cicd-overwatch-diagnose-recommend"], try(var.workflow_skill_refs["cicd-overwatch-jenkins-rca::diagnose-and-recommend"], []))
      note             = "Classify the failure, rule out an alternative, recommend the smallest safe fix."
    },
    {
      stage_id         = "post-linear-rca"
      agent_ref        = sg_agent.investigator.name
      stage_depends_on = ["diagnose-and-recommend"]
      runbook_refs     = [sg_runbook_sop.post_linear_rca.name]
      skill_refs       = concat(["cicd-overwatch-post-rca"], try(var.workflow_skill_refs["cicd-overwatch-jenkins-rca::post-linear-rca"], []))
      note             = "Post a concise, structured RCA comment back to Linear."
    },
    {
      stage_id         = "optional-approved-remediation"
      agent_ref        = sg_agent.investigator.name
      stage_depends_on = ["post-linear-rca"]
      runbook_refs     = [sg_runbook_sop.approved_remediation.name]
      skill_refs       = concat(["cicd-overwatch-safe-remediation"], try(var.workflow_skill_refs["cicd-overwatch-jenkins-rca::optional-approved-remediation"], []))
      note             = "Only act with explicit operator approval; otherwise report remediation as pending approval."
    },
  ]
}

# =============================================================================
# Linear webhook ingress
# =============================================================================

resource "sg_webhook" "cicd_overwatch_linear_ticket_receiver" {
  count = var.enable_linear_webhook ? 1 : 0

  name          = local.webhook_name
  target_type   = "workflow"
  target_name   = sg_workflow.cicd_overwatch_jenkins_rca.name
  action        = "A Linear ticket reporting a CICD Overwatch / Jenkins CI/CD failure was created or updated. Claim it, read context, collect live Jenkins evidence, diagnose and recommend a fix, post an RCA to Linear, and apply remediation only if explicitly approved."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
