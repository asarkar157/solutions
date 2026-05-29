terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  module_prefix = "aws-sre"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name           = "aws-sre${local.suffix}"
  policy_governance_id = "aws-tool-governance${local.suffix}"

  sop_k8s_diag_name  = "k8s-diagnostics${local.suffix}"
  sop_sec_audit_name = "aws-security-audit${local.suffix}"
  sop_cost_name      = "aws-cost-analysis${local.suffix}"
  sop_tags_name      = "aws-tags-sanity${local.suffix}"

  workflow_k8s_name   = "k8s-monitoring${local.suffix}"
  workflow_audit_name = "aws-unified-audit${local.suffix}"

  aws_integration_name = "${local.module_prefix}-aws${local.suffix}"

  # `provision_aws` must be plan-time known (drives `count`). Consumers may
  # forward a computed `aws_secret_id` (e.g. `module.aws_integration[0].secret_id`)
  # so we don't inspect it here. The inner aios-integration-aws module
  # surfaces a clear error when both inputs are missing.
  provision_aws = trimspace(var.existing_aws_integration_name) == ""

  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
}

resource "terraform_data" "aws_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_aws_integration_name) != ""
      error_message = "aios-agent-aws-sre needs an AWS Guild integration: provide `aws_secret_id` (the module provisions one) or `existing_aws_integration_name` (the module attaches to it)."
    }
  }
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
  description        = "AWS Guild integration owned by the ${local.agent_name} agent (read-only audit + diagnostics)."
}

# =============================================================================
# AWS SRE Agent Module
# =============================================================================

resource "sg_policy" "aws_tool_governance" {
  name        = local.policy_governance_id
  description = trimspace(templatefile("${path.module}/templates/policy-aws-tool-governance.md", {}))
  type        = "logic"
  rego_source = file("${path.module}/policies/aws-tool-governance.rego")
}

resource "sg_agent" "aws_sre" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/aws-sre.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = [
      "${local.resolved_aws_integration_name}_test_connection",
      "${local.resolved_aws_integration_name}_execute_command"
    ]
  }

  integrations = [local.resolved_aws_integration_name]
}

resource "sg_agent_budget" "aws_sre" {
  agent_name  = sg_agent.aws_sre.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.aws_sre.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "aws_tool_governance" {
  agent_name = sg_agent.aws_sre.name
  policy_id  = sg_policy.aws_tool_governance.id
  enabled    = true
}

# --- Runbooks ---

resource "sg_runbook_sop" "k8s_diagnostics" {
  name        = local.sop_k8s_diag_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/k8s-diagnostics.md", {}))
}

resource "sg_runbook_sop" "aws_security_audit" {
  name        = local.sop_sec_audit_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/aws-security-audit.md", {}))
}

resource "sg_runbook_sop" "aws_cost_analysis" {
  name        = local.sop_cost_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/aws-cost-analysis.md", {}))
}

resource "sg_runbook_sop" "aws_tags_sanity" {
  name        = local.sop_tags_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/aws-tags-sanity.md", {}))
}

# --- Workflows ---

resource "sg_workflow" "k8s_monitoring" {
  name        = local.workflow_k8s_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-k8s-monitoring.md", {}))
  approve     = true

  triggers        = [{ field = "incident_title_contains", values = ["CrashLoopBackOff", "NodeNotReady"], type = "passive" }]
  required_inputs = ["cluster_name"]
  runbook_refs    = [sg_runbook_sop.k8s_diagnostics.name]

  example_queries = ["Pod in default namespace is crashing", "Node CPU pressure reported in EKS"]

  stages         = [{ stage_id = "check-pod-health", description = "Check pod logs and events.", note = "Run kubectl commands.", required = true }]
  stage_bindings = [{ stage_id = "check-pod-health", agent_ref = sg_agent.aws_sre.name, note = "AWS SRE diagnosing K8s", skill_refs = concat(["aws-eks-pod-diagnostics"], try(var.workflow_skill_refs["${local.workflow_k8s_name}::check-pod-health"], [])) }]
}

resource "sg_workflow" "aws_unified_audit" {
  name        = local.workflow_audit_name
  domain      = "sre-operations"
  description = trimspace(templatefile("${path.module}/templates/workflow-aws-unified-audit.md", {}))
  approve     = true

  runbook_refs    = [sg_runbook_sop.aws_security_audit.name, sg_runbook_sop.aws_cost_analysis.name, sg_runbook_sop.aws_tags_sanity.name]
  example_queries = ["Run a security check on S3 buckets", "Find idle EBS volumes", "Validate tagging compliance"]

  stages = [
    { stage_id = "perform-security-scan", description = "Identify public S3 buckets or open SSH ports.", note = "Use AWS CLI.", required = true },
    { stage_id = "analyze-costs", description = "Scan for unattached volumes and EIPs.", required = true },
    { stage_id = "validate-tags", description = "Check resources for required tags.", required = true },
    { stage_id = "consolidate-findings", description = "Consolidate results and generate report.", required = true },
  ]

  stage_bindings = [
    { stage_id = "perform-security-scan", agent_ref = sg_agent.aws_sre.name, note = "Security audit", skill_refs = concat(["aws-security-posture-scan"], try(var.workflow_skill_refs["${local.workflow_audit_name}::perform-security-scan"], [])) },
    { stage_id = "analyze-costs", agent_ref = sg_agent.aws_sre.name, note = "Cost analysis", skill_refs = concat(["aws-cost-idle-resources"], try(var.workflow_skill_refs["${local.workflow_audit_name}::analyze-costs"], [])) },
    { stage_id = "validate-tags", agent_ref = sg_agent.aws_sre.name, note = "Tag validation", skill_refs = concat(["aws-tag-governance"], try(var.workflow_skill_refs["${local.workflow_audit_name}::validate-tags"], [])) },
    { stage_id = "consolidate-findings", agent_ref = sg_agent.aws_sre.name, stage_depends_on = ["perform-security-scan", "analyze-costs", "validate-tags"], note = "Consolidation", skill_refs = concat(["aws-audit-executive-summary"], try(var.workflow_skill_refs["${local.workflow_audit_name}::consolidate-findings"], [])) },
  ]
}
