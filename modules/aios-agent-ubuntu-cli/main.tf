terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  module_prefix = "ubuntu-cli-inspector"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name       = "ubuntu-cli-inspector${local.suffix}"
  sop_network_name = "ubuntu-network-diagnostics${local.suffix}"
  sop_process_name = "ubuntu-process-triage${local.suffix}"
  sop_disk_name    = "ubuntu-disk-triage${local.suffix}"
  sop_log_name     = "ubuntu-log-analysis${local.suffix}"

  ubuntu_integration_name = "ubuntu-cli${local.suffix}"

  provision_ubuntu = trimspace(var.existing_ubuntu_integration_name) == ""

  resolved_ubuntu_integration_name = trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : (
    local.provision_ubuntu ? module.ubuntu_integration[0].integration_name : ""
  )
}

module "ubuntu_integration" {
  count  = local.provision_ubuntu ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = compact([var.github_secret_id])
  install_tools    = var.install_tools
}

# ============================================================================
# Ubuntu CLI SRE Module
# ============================================================================
# Dedicated OS inspection agent with deep Linux systems expertise.
# Designed for read-only diagnostics: connectivity testing, process
# triage, memory pressure analysis, and log foraging.
#
# Uses a standard MCP container loaded with typical Linux diagnostic tools.

# ============================================================================
# Agent
# ============================================================================

resource "sg_agent" "ubuntu_cli_agent" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/ubuntu-sre.md")
  model_names = compact(var.model_names)

  integrations = compact([local.resolved_ubuntu_integration_name])
}

# ============================================================================
# Agent Budget
# ============================================================================

resource "sg_agent_budget" "ubuntu_cli_agent" {
  agent_name  = sg_agent.ubuntu_cli_agent.name
  limit_usd   = 10
  period_type = "daily"
}

# ============================================================================
# Policy Attachments
# ============================================================================

resource "sg_agent_policy_attachment" "ubuntu_dangerous_ops" {
  agent_name = sg_agent.ubuntu_cli_agent.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "ubuntu_shell_hitl" {
  agent_name = sg_agent.ubuntu_cli_agent.name
  policy_id  = var.policy_ids.container_shell_hitl
  enabled    = true
}

# ============================================================================
# Runbook SOPs — Granular Linux Triage Skills
# ============================================================================

resource "sg_runbook_sop" "ubuntu_network_diagnostics" {
  name        = local.sop_network_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/ubuntu-network-diagnostics.md", {}))
}

resource "sg_runbook_sop" "ubuntu_process_triage" {
  name        = local.sop_process_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/ubuntu-process-triage.md", {}))
}

resource "sg_runbook_sop" "ubuntu_disk_triage" {
  name        = local.sop_disk_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/ubuntu-disk-triage.md", {}))
}

resource "sg_runbook_sop" "ubuntu_log_analysis" {
  name        = local.sop_log_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/ubuntu-log-analysis.md", {}))
}
