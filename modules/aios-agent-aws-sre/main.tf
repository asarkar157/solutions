terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.9, < 0.2.0" }
  }
}

# =============================================================================
# AWS SRE Agent Module
# =============================================================================

resource "sg_policy" "aws_tool_governance" {
  name        = "aws-tool-governance"
  description = trimspace(templatefile("${path.module}/templates/policy-aws-tool-governance.md", {}))
  type        = "logic"
  rego_source = file("${path.module}/policies/aws-tool-governance.rego")
}

resource "sg_agent" "aws_sre" {
  name        = "aws-sre"
  persona     = file("${path.module}/personas/aws-sre.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  hitl = {
    always_allowed = [
      "${var.integration_name}_test_connection",
      "${var.integration_name}_execute_command"
    ]
  }

  integrations = compact([var.integration_name])
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
  name        = "k8s-diagnostics"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/k8s-diagnostics.md", {}))
}

resource "sg_runbook_sop" "aws_security_audit" {
  name        = "aws-security-audit"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/aws-security-audit.md", {}))
}

resource "sg_runbook_sop" "aws_cost_analysis" {
  name        = "aws-cost-analysis"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/aws-cost-analysis.md", {}))
}

resource "sg_runbook_sop" "aws_tags_sanity" {
  name        = "aws-tags-sanity"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/aws-tags-sanity.md", {}))
}

# --- Workflows ---

resource "sg_workflow" "k8s_monitoring" {
  name        = "k8s-monitoring"
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-k8s-monitoring.md", {}))
  approve     = true

  triggers        = [{ field = "incident_title_contains", values = ["CrashLoopBackOff", "NodeNotReady"], type = "passive" }]
  required_inputs = ["cluster_name"]
  runbook_refs    = [sg_runbook_sop.k8s_diagnostics.name]

  example_queries = ["Pod in default namespace is crashing", "Node CPU pressure reported in EKS"]

  stages         = [{ stage_id = "check-pod-health", description = "Check pod logs and events.", note = "Run kubectl commands.", required = true }]
  stage_bindings = [{ stage_id = "check-pod-health", agent_ref = sg_agent.aws_sre.name, note = "AWS SRE diagnosing K8s", skill_refs = concat(["aws-eks-pod-diagnostics"], try(var.workflow_skill_refs["k8s-monitoring::check-pod-health"], [])) }]
}

resource "sg_workflow" "aws_unified_audit" {
  name        = "aws-unified-audit"
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
    { stage_id = "perform-security-scan", agent_ref = sg_agent.aws_sre.name, note = "Security audit", skill_refs = concat(["aws-security-posture-scan"], try(var.workflow_skill_refs["aws-unified-audit::perform-security-scan"], [])) },
    { stage_id = "analyze-costs", agent_ref = sg_agent.aws_sre.name, note = "Cost analysis", skill_refs = concat(["aws-cost-idle-resources"], try(var.workflow_skill_refs["aws-unified-audit::analyze-costs"], [])) },
    { stage_id = "validate-tags", agent_ref = sg_agent.aws_sre.name, note = "Tag validation", skill_refs = concat(["aws-tag-governance"], try(var.workflow_skill_refs["aws-unified-audit::validate-tags"], [])) },
    { stage_id = "consolidate-findings", agent_ref = sg_agent.aws_sre.name, stage_depends_on = ["perform-security-scan", "analyze-costs", "validate-tags"], note = "Consolidation", skill_refs = concat(["aws-audit-executive-summary"], try(var.workflow_skill_refs["aws-unified-audit::consolidate-findings"], [])) },
  ]
}
