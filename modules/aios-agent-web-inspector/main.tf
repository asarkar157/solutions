terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

# =============================================================================
# Web Inspector Agent — Chrome + Grafana + GitHub + Ubuntu
#
# This agent combines browser automation (Chrome), observability (Grafana),
# source code context (GitHub), and OS-level diagnostics (Ubuntu CLI) to
# perform cross-signal frontend-to-backend triage.
#
# Example use cases:
#   - Visual regression detection: screenshot pages and compare
#   - Frontend performance audits: Core Web Vitals + Grafana backend metrics
#   - E2E smoke testing: navigate flows, check console errors, verify APIs
#   - Incident triage: correlate user-facing errors with backend metrics
# =============================================================================

locals {
  module_prefix = "web-inspector"
  suffix        = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name         = "${local.module_prefix}${local.suffix}"
  chrome_integration = "chrome-browser${local.suffix}"
  ubuntu_integration = "ubuntu-cli${local.suffix}"

  provision_chrome = trimspace(var.existing_chrome_integration_name) == ""
  provision_ubuntu = trimspace(var.existing_ubuntu_integration_name) == ""

  resolved_chrome = local.provision_chrome ? module.chrome_integration[0].integration_name : var.existing_chrome_integration_name
  resolved_ubuntu = local.provision_ubuntu ? module.ubuntu_integration[0].integration_name : var.existing_ubuntu_integration_name

  # Grafana is optional — only include if a name is provided.
  all_integrations = compact([
    local.resolved_chrome,
    local.resolved_ubuntu,
    var.grafana_integration_name,
    var.github_integration_name,
  ])
}

# =============================================================================
# Self-contained integrations (provisioned when no existing name is given)
# =============================================================================

module "chrome_integration" {
  count  = local.provision_chrome ? 1 : 0
  source = "../aios-integration-chrome"

  integration_name = local.chrome_integration
  allowed_domains  = var.chrome_allowed_domains
  max_tabs         = var.chrome_max_tabs
}

module "ubuntu_integration" {
  count  = local.provision_ubuntu ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration
  secret_ref_ids   = compact([var.github_secret_id])
  install_tools    = ["curl", "jq", "git"]
}

# =============================================================================
# Agent
# =============================================================================

resource "sg_agent" "web_inspector" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/web-inspector.md")
  model_names = compact(var.model_names)

  integrations = local.all_integrations
}

# =============================================================================
# Budget
# =============================================================================

resource "sg_agent_budget" "web_inspector" {
  agent_name  = sg_agent.web_inspector.name
  limit_usd   = 10
  period_type = "daily"
}

# =============================================================================
# Policy Attachments
# =============================================================================

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.web_inspector.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "container_shell_hitl" {
  agent_name = sg_agent.web_inspector.name
  policy_id  = var.policy_ids.container_shell_hitl
  enabled    = true
}

# =============================================================================
# Runbook SOPs
# =============================================================================

resource "sg_runbook_sop" "visual_smoke_test" {
  name        = "web-visual-smoke-test${local.suffix}"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/visual-smoke-test.md", {}))
}

resource "sg_runbook_sop" "frontend_performance_audit" {
  name        = "web-frontend-performance-audit${local.suffix}"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/frontend-performance-audit.md", {}))
}

resource "sg_runbook_sop" "cross_signal_triage" {
  name        = "web-cross-signal-triage${local.suffix}"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cross-signal-triage.md", {}))
}
