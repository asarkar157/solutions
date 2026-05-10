# =============================================================================
# AIOS Policies Module
# =============================================================================
# Central library of reusable OPA/Rego guardrail policies for AI agent governance.
# Each policy can be individually enabled/disabled via the create_policies variable.

# =============================================================================
# Intervention Policies (require human approval)
# =============================================================================

resource "sg_policy" "dangerous_ops" {
  count       = var.create_policies.dangerous_ops ? 1 : 0
  name        = "dangerous-ops"
  description = "Blocks destructive operations (delete, terminate, destroy) across all agents"
  type        = "intervention"
  rego_source = file("${path.module}/policies/dangerous-ops.rego")
}

resource "sg_policy" "sre_remediation" {
  count       = var.create_policies.sre_remediation ? 1 : 0
  name        = "hitl-sre-remediation"
  description = "Auto-remediation, PagerDuty escalation, and alert rule changes require approval"
  type        = "intervention"
  rego_source = file("${path.module}/policies/sre-remediation.rego")
}

resource "sg_policy" "prod_write_gate" {
  count       = var.create_policies.prod_write_gate ? 1 : 0
  name        = "prod-write-gate"
  description = "Production write actions require service-owner or on-call acknowledgement"
  type        = "intervention"
  rego_source = file("${path.module}/policies/prod-write-gate.rego")
}

resource "sg_policy" "blast_radius_limit" {
  count       = var.create_policies.blast_radius_limit ? 1 : 0
  name        = "blast-radius-limit"
  description = "Actions must target ≤ 5 pods / ≤ 3 nodes / single region without approval"
  type        = "intervention"
  rego_source = file("${path.module}/policies/blast-radius-limit.rego")
}

resource "sg_policy" "post_action_verification" {
  count       = var.create_policies.post_action_verification ? 1 : 0
  name        = "post-action-verification"
  description = "Broader rollout requires SLI health confirmation and zero new alerts for ≥ 10 minutes"
  type        = "intervention"
  rego_source = file("${path.module}/policies/post-action-verification.rego")
}

resource "sg_policy" "container_shell_hitl" {
  count       = var.create_policies.container_shell_hitl ? 1 : 0
  name        = "container-shell-hitl-policy"
  description = "Require human-in-the-loop approval for container execution tool calls"
  type        = "intervention"
  rego_source = file("${path.module}/policies/container-shell-hitl.rego")
}

# =============================================================================
# Logic Policies (evaluate conditions without requiring approval)
# =============================================================================

resource "sg_policy" "hitl_approval_evaluation" {
  count       = var.create_policies.hitl_approval_evaluation ? 1 : 0
  name        = "hitl-approval-evaluation"
  description = "Evaluates whether an approver is authorized to approve a tool execution"
  type        = "logic"
  rego_source = file("${path.module}/policies/hitl-approval.rego")
}

resource "sg_policy" "tier0_service_protection" {
  count       = var.create_policies.tier0_service_protection ? 1 : 0
  name        = "tier0-service-protection"
  description = "Tier-0 services only allow safe actions (read-only, diagnostics, canary restart)"
  type        = "logic"
  rego_source = file("${path.module}/policies/tier0-service-protection.rego")
}

resource "sg_policy" "freeze_window" {
  count       = var.create_policies.freeze_window ? 1 : 0
  name        = "freeze-window"
  description = "Deny deploy and config changes during active freeze windows unless exception exists"
  type        = "logic"
  rego_source = file("${path.module}/policies/freeze-window.rego")
}

resource "sg_policy" "data_risk_pii" {
  count       = var.create_policies.data_risk_pii ? 1 : 0
  name        = "data-risk-pii"
  description = "Log exports and data queries on PII/PCI/PHI classified data require redaction pipeline"
  type        = "logic"
  rego_source = file("${path.module}/policies/data-risk-pii.rego")
}

resource "sg_policy" "azure_tool_governance" {
  count       = var.create_policies.azure_tool_governance ? 1 : 0
  name        = "azure-tool-governance"
  description = "Allows read-only Azure CLI, kubectl, and ClickHouse SELECT queries. Blocks destructive operations."
  type        = "logic"
  rego_source = file("${path.module}/policies/azure-tool-governance.rego")
}

resource "sg_policy" "google_tool_governance" {
  count       = var.create_policies.google_tool_governance ? 1 : 0
  name        = "google-tool-governance"
  description = "Allows all workspace tools. Blocks all shell and dangerous operations."
  type        = "logic"
  rego_source = file("${path.module}/policies/google-tool-governance.rego")
}

resource "sg_policy" "langfuse_observability" {
  count       = var.create_policies.langfuse_observability ? 1 : 0
  name        = "langfuse-observability"
  description = "Enforces read-only access for Langfuse observer agents — blocks create/update/delete/archive mutations and shell exec"
  type        = "logic"
  rego_source = file("${path.module}/policies/langfuse-observability.rego")
}

# =============================================================================
# Policy Bundle
# =============================================================================

resource "sg_policy_bundle" "standard_guardrails" {
  count       = var.create_policy_bundle ? 1 : 0
  name        = "standard-guardrails"
  description = "Baseline safety policies applied to all SRE agents"
  version     = 1
}
