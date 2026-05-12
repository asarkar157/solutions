terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.10, < 0.2.0" }
  }
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
  name        = "ubuntu-cli-inspector"
  persona     = file("${path.module}/personas/ubuntu-sre.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]

  integrations = [var.integration_names.ubuntu_cli]
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
  name        = "ubuntu-network-diagnostics"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/ubuntu-network-diagnostics.md", {}))
}

resource "sg_runbook_sop" "ubuntu_process_triage" {
  name        = "ubuntu-process-triage"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/ubuntu-process-triage.md", {}))
}

resource "sg_runbook_sop" "ubuntu_disk_triage" {
  name        = "ubuntu-disk-triage"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/ubuntu-disk-triage.md", {}))
}

resource "sg_runbook_sop" "ubuntu_log_analysis" {
  name        = "ubuntu-log-analysis"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/ubuntu-log-analysis.md", {}))
}
