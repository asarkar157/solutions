terraform {
  required_version = ">= 1.5"
  required_providers {
    sg      = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.5, < 0.2.0" }
    azurerm = { source = "hashicorp/azurerm" }
  }
}

# =============================================================================
# Azure DevOps SRE Agent Module
# =============================================================================

resource "sg_agent" "azure_devops_sre" {
  name        = "azure-devops-sre"
  persona     = file("${path.module}/personas/azure-devops-sre.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]

  hitl = {
    always_allowed = concat(["azure-production_test_connection"], var.azure_readonly_tools)
  }

  integrations = compact([
    lookup(var.integration_names, "azure", ""),
    lookup(var.integration_names, "slack", "") != "" ? var.integration_names.slack : null,
  ])
}

resource "sg_agent_budget" "azure_devops_sre" {
  agent_name  = sg_agent.azure_devops_sre.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

locals {
  clickhouse_agent = var.clickhouse_inspector_agent_name != "" ? var.clickhouse_inspector_agent_name : sg_agent.azure_devops_sre.name
}

# Policy attachments
resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.azure_devops_sre.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "prod_write_gate" {
  count      = var.policy_ids.prod_write_gate != "" ? 1 : 0
  agent_name = sg_agent.azure_devops_sre.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_remediation" {
  count      = var.policy_ids.sre_remediation != "" ? 1 : 0
  agent_name = sg_agent.azure_devops_sre.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "container_shell_hitl" {
  count      = var.policy_ids.container_shell_hitl != "" ? 1 : 0
  agent_name = sg_agent.azure_devops_sre.name
  policy_id  = var.policy_ids.container_shell_hitl
  enabled    = true
}

# Runbooks
resource "sg_runbook_sop" "azure_function_health" {
  name        = "azure-function-health-check"
  description = trimspace(templatefile("${path.module}/templates/azure-function-health-check.md", {}))
}

resource "sg_runbook_sop" "clickhouse_diagnostics" {
  name        = "clickhouse-cluster-diagnostics"
  description = trimspace(templatefile("${path.module}/templates/clickhouse-cluster-diagnostics.md", {}))
}

resource "sg_runbook_sop" "storage_queue_inspection" {
  name        = "storage-queue-inspection"
  description = trimspace(templatefile("${path.module}/templates/storage-queue-inspection.md", {}))
}

resource "sg_runbook_sop" "blob_storage_monitoring" {
  name        = "blob-storage-monitoring"
  description = trimspace(templatefile("${path.module}/templates/blob-storage-monitoring.md", {}))
}

# Remediation patterns
resource "sg_remediation_pattern" "restart_azure_function" {
  name              = "restart-azure-function"
  description       = trimspace(templatefile("${path.module}/templates/remediation-restart-azure-function.md", {}))
  version           = 1
  risk_level        = "medium"
  blast_radius      = "single-function"
  requires_approval = true
}

resource "sg_remediation_pattern" "redeploy_log_processor" {
  name              = "redeploy-log-processor"
  description       = trimspace(templatefile("${path.module}/templates/remediation-redeploy-log-processor.md", {}))
  version           = 1
  risk_level        = "high"
  blast_radius      = "data-pipeline"
  requires_approval = true
}

# Evidence checklist
resource "sg_evidence_checklist" "azure_devops_incident" {
  name        = "azure-devops-incident"
  description = trimspace(templatefile("${path.module}/templates/evidence-azure-devops-incident.md", {}))
}

# Workflow — 5-stage DAG
resource "sg_workflow" "azure_devops_full_triage" {
  name        = "azure-devops-full-triage"
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-azure-devops-full-triage.md", {}))
  approve     = true

  triggers = [
    { field = "incident_title_contains", values = ["poison queue", "clickhouse", "azure function", "ingestion failure"], type = "passive" },
  ]

  required_inputs        = ["environment"]
  optional_inputs        = ["incident_id", "queue_name", "function_name"]
  evidence_checklist_ref = sg_evidence_checklist.azure_devops_incident.name

  example_queries = [
    "Poison queue is growing, check ClickHouse",
    "Azure function failing to insert into ClickHouse",
    "ClickHouse cluster seems slow, run diagnostics",
  ]

  stages = [
    { stage_id = "check-clickhouse", description = "ClickHouse system table diagnostics.", required = true },
    { stage_id = "check-queues", description = "Storage queue inspection.", required = true },
    { stage_id = "check-functions", description = "Azure Function health checks.", required = true },
    { stage_id = "correlate", description = "Cross-reference all signals.", required = true },
    { stage_id = "remediate", description = "Recommend and execute remediation.", required = true },
  ]

  stage_bindings = [
    { stage_id = "check-clickhouse", agent_ref = local.clickhouse_agent, runbook_refs = [sg_runbook_sop.clickhouse_diagnostics.name] },
    { stage_id = "check-queues", agent_ref = sg_agent.azure_devops_sre.name, runbook_refs = [sg_runbook_sop.storage_queue_inspection.name] },
    { stage_id = "check-functions", agent_ref = sg_agent.azure_devops_sre.name, runbook_refs = [sg_runbook_sop.azure_function_health.name] },
    { stage_id = "correlate", agent_ref = sg_agent.azure_devops_sre.name, stage_depends_on = ["check-clickhouse", "check-queues", "check-functions"] },
    { stage_id = "remediate", agent_ref = sg_agent.azure_devops_sre.name, stage_depends_on = ["correlate"] },
  ]
}
