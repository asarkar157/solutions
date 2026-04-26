terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.0" }
  }
}

# =============================================================================
# AWS SRE Agent Module
# =============================================================================

resource "sg_policy" "aws_tool_governance" {
  name        = "aws-tool-governance"
  description = "Allows read-only AWS CLI and kubectl commands. Blocks destructive operations."
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
  description = "Diagnose Kubernetes pod crashes and node pressure. Steps: 1) Get nodes, 2) Describe failing pods, 3) Check pod logs, 4) Check events."
}

resource "sg_runbook_sop" "aws_security_audit" {
  name        = "aws-security-audit"
  description = "Security audit on AWS resources. Steps: 1) List S3 buckets, 2) Check public access block, 3) Check IAM roles, 4) Inspect security groups with 0.0.0.0/0."
}

resource "sg_runbook_sop" "aws_cost_analysis" {
  name        = "aws-cost-analysis"
  description = "Identify idle AWS resources for cost optimization. Steps: 1) Find unattached EBS, 2) Find unassociated Elastic IPs, 3) Find stopped EC2 instances."
}

resource "sg_runbook_sop" "aws_tags_sanity" {
  name        = "aws-tags-sanity"
  description = "Verify resource tagging compliance. Steps: 1) Check EC2 tags, 2) Check RDS tags, 3) Check for missing required tags."
}

# --- Workflows ---

resource "sg_workflow" "k8s_monitoring" {
  name        = "k8s-monitoring"
  domain      = "incident-response"
  description = "Diagnose Kubernetes cluster issues such as CrashLoopBackOff or node pressure."

  triggers        = [{ field = "incident_title_contains", values = ["CrashLoopBackOff", "NodeNotReady"], type = "passive" }]
  required_inputs = ["cluster_name"]
  runbook_refs    = [sg_runbook_sop.k8s_diagnostics.name]

  example_queries = ["Pod in default namespace is crashing", "Node CPU pressure reported in EKS"]

  stages         = [{ stage_id = "check-pod-health", description = "Check pod logs and events.", note = "Run kubectl commands.", required = true }]
  stage_bindings = [{ stage_id = "check-pod-health", agent_ref = sg_agent.aws_sre.name, note = "AWS SRE diagnosing K8s" }]
}

resource "sg_workflow" "aws_unified_audit" {
  name        = "aws-unified-audit"
  domain      = "sre-operations"
  description = "Comprehensive AWS environment audit for security, cost, and compliance."

  runbook_refs    = [sg_runbook_sop.aws_security_audit.name, sg_runbook_sop.aws_cost_analysis.name, sg_runbook_sop.aws_tags_sanity.name]
  example_queries = ["Run a security check on S3 buckets", "Find idle EBS volumes", "Validate tagging compliance"]

  stages = [
    { stage_id = "perform-security-scan", description = "Identify public S3 buckets or open SSH ports.", note = "Use AWS CLI.", required = true },
    { stage_id = "analyze-costs", description = "Scan for unattached volumes and EIPs.", required = true },
    { stage_id = "validate-tags", description = "Check resources for required tags.", required = true },
    { stage_id = "consolidate-findings", description = "Consolidate results and generate report.", required = true },
  ]

  stage_bindings = [
    { stage_id = "perform-security-scan", agent_ref = sg_agent.aws_sre.name, note = "Security audit" },
    { stage_id = "analyze-costs", agent_ref = sg_agent.aws_sre.name, note = "Cost analysis" },
    { stage_id = "validate-tags", agent_ref = sg_agent.aws_sre.name, note = "Tag validation" },
    { stage_id = "consolidate-findings", agent_ref = sg_agent.aws_sre.name, stage_depends_on = ["perform-security-scan", "analyze-costs", "validate-tags"], note = "Consolidation" },
  ]
}
