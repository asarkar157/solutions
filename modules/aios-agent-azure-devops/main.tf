terraform {
  required_version = ">= 1.5"
  required_providers {
    sg      = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
    azurerm = { source = "hashicorp/azurerm" }
  }
}

locals {
  module_prefix = "azure-devops-sre"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name             = "azure-devops-sre${local.suffix}"
  workflow_name          = "azure-devops-full-triage${local.suffix}"
  sop_function_name      = "azure-function-health-check${local.suffix}"
  sop_clickhouse_name    = "clickhouse-cluster-diagnostics${local.suffix}"
  sop_storage_queue_name = "storage-queue-inspection${local.suffix}"
  sop_blob_name          = "blob-storage-monitoring${local.suffix}"
  pattern_restart_name   = "restart-azure-function${local.suffix}"
  pattern_redeploy_name  = "redeploy-log-processor${local.suffix}"
  evidence_name          = "azure-devops-incident${local.suffix}"

  azure_integration_name = "${local.module_prefix}-azure${local.suffix}"
  slack_integration_name = "${local.module_prefix}-slack${local.suffix}"

  provision_azure = trimspace(var.azure_secret_id) != "" && trimspace(var.existing_azure_integration_name) == ""
  provision_slack = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""

  resolved_azure_integration_name = trimspace(var.existing_azure_integration_name) != "" ? var.existing_azure_integration_name : (
    local.provision_azure ? module.azure_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )

  clickhouse_agent = var.clickhouse_inspector_agent_name != "" ? var.clickhouse_inspector_agent_name : sg_agent.azure_devops_sre.name
}

module "azure_integration" {
  count  = local.provision_azure ? 1 : 0
  source = "../aios-integration-azure"

  integration_name   = local.azure_integration_name
  existing_secret_id = var.azure_secret_id
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

# =============================================================================
# Azure DevOps SRE Agent Module
# =============================================================================

resource "sg_agent" "azure_devops_sre" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/azure-devops-sre.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = concat(
      local.resolved_azure_integration_name != "" ? ["${local.resolved_azure_integration_name}_test_connection"] : [],
      var.azure_readonly_tools,
    )
  }

  integrations = compact([
    local.resolved_azure_integration_name,
    local.resolved_slack_integration_name,
  ])
}

resource "sg_agent_budget" "azure_devops_sre" {
  agent_name  = sg_agent.azure_devops_sre.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

# Policy attachments
resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.azure_devops_sre.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "prod_write_gate" {
  count      = try(var.policy_create_flags.prod_write_gate, true) ? 1 : 0
  agent_name = sg_agent.azure_devops_sre.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_remediation" {
  count      = try(var.policy_create_flags.sre_remediation, true) ? 1 : 0
  agent_name = sg_agent.azure_devops_sre.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "container_shell_hitl" {
  count      = try(var.policy_create_flags.container_shell_hitl, true) ? 1 : 0
  agent_name = sg_agent.azure_devops_sre.name
  policy_id  = var.policy_ids.container_shell_hitl
  enabled    = true
}

# Runbooks
resource "sg_runbook_sop" "azure_function_health" {
  name        = local.sop_function_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/azure-function-health-check.md", {}))
}

resource "sg_runbook_sop" "clickhouse_diagnostics" {
  name        = local.sop_clickhouse_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-cluster-diagnostics.md", {}))
}

resource "sg_runbook_sop" "storage_queue_inspection" {
  name        = local.sop_storage_queue_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/storage-queue-inspection.md", {}))
}

resource "sg_runbook_sop" "blob_storage_monitoring" {
  name        = local.sop_blob_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/blob-storage-monitoring.md", {}))
}

# Remediation patterns
resource "sg_remediation_pattern" "restart_azure_function" {
  name              = local.pattern_restart_name
  description       = trimspace(templatefile("${path.module}/templates/remediation-restart-azure-function.md", {}))
  risk_level        = "medium"
  blast_radius      = "single-function"
  requires_approval = true
  approve           = true
}

resource "sg_remediation_pattern" "redeploy_log_processor" {
  name              = local.pattern_redeploy_name
  description       = trimspace(templatefile("${path.module}/templates/remediation-redeploy-log-processor.md", {}))
  risk_level        = "high"
  blast_radius      = "data-pipeline"
  requires_approval = true
  approve           = true
}

# Evidence checklist
resource "sg_evidence_checklist" "azure_devops_incident" {
  name        = local.evidence_name
  description = trimspace(templatefile("${path.module}/templates/evidence-azure-devops-incident.md", {}))
  approve     = true
  required_items = [
    "clickhouse_diagnostics_summary",
    "storage_queue_depth_snapshot",
    "function_invocation_errors_captured",
  ]
  optional_items = ["previous_known_good_deploy_identified"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.7
  }
  metadata = { playbook = "azure-devops-triage" }
}

# Workflow — 5-stage DAG
resource "sg_workflow" "azure_devops_full_triage" {
  name        = local.workflow_name
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
    { stage_id = "check-clickhouse", agent_ref = local.clickhouse_agent, runbook_refs = [sg_runbook_sop.clickhouse_diagnostics.name], skill_refs = concat(["azure-clickhouse-diagnostics"], try(var.workflow_skill_refs["azure-devops-full-triage::check-clickhouse"], [])) },
    { stage_id = "check-queues", agent_ref = sg_agent.azure_devops_sre.name, runbook_refs = [sg_runbook_sop.storage_queue_inspection.name], skill_refs = concat(["azure-storage-queue-triage"], try(var.workflow_skill_refs["azure-devops-full-triage::check-queues"], [])) },
    { stage_id = "check-functions", agent_ref = sg_agent.azure_devops_sre.name, runbook_refs = [sg_runbook_sop.azure_function_health.name], skill_refs = concat(["azure-functions-health"], try(var.workflow_skill_refs["azure-devops-full-triage::check-functions"], [])) },
    { stage_id = "correlate", agent_ref = sg_agent.azure_devops_sre.name, stage_depends_on = ["check-clickhouse", "check-queues", "check-functions"], skill_refs = concat(["azure-cross-signal-correlation"], try(var.workflow_skill_refs["azure-devops-full-triage::correlate"], [])) },
    { stage_id = "remediate", agent_ref = sg_agent.azure_devops_sre.name, stage_depends_on = ["correlate"], skill_refs = concat(["azure-incident-remediation"], try(var.workflow_skill_refs["azure-devops-full-triage::remediate"], [])) },
  ]
}

# ============================================================================
# Role Assignments
# ============================================================================

# Assign Storage Queue Data Reader for data-plane queue access to the reader instance
resource "azurerm_role_assignment" "storage_queue_reader" {
  count                = var.reader_principal_id != "" && var.azure_role_scope != "" ? 1 : 0
  scope                = var.azure_role_scope
  role_definition_name = "Storage Queue Data Reader"
  principal_id         = var.reader_principal_id
}

# Assign Function App configuration reader for diagnostic access
resource "azurerm_role_definition" "function_config_reader" {
  count       = var.reader_principal_id != "" && var.azure_role_scope != "" ? 1 : 0
  name        = "SRE Function Config Reader - ${var.reader_principal_id}"
  scope       = var.azure_role_scope
  description = "Allows reading Function App configuration (connection strings, etc.) for diagnostics"

  permissions {
    actions     = ["Microsoft.Web/sites/config/list/action"]
    not_actions = []
  }

  assignable_scopes = [
    var.azure_role_scope
  ]
}

resource "azurerm_role_assignment" "function_config_reader_assignment" {
  count              = var.reader_principal_id != "" && var.azure_role_scope != "" ? 1 : 0
  scope              = var.azure_role_scope
  role_definition_id = azurerm_role_definition.function_config_reader[0].role_definition_resource_id
  principal_id       = var.reader_principal_id
}
