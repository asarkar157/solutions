terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.18, < 0.2.0" }
  }
}

locals {
  module_prefix = "soc-analyst"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name            = "soc-analyst${local.suffix}"
  workflow_triage_name  = "soc-alert-triage${local.suffix}"
  workflow_hunt_name    = "soc-threat-hunt${local.suffix}"
  sop_alert_triage_name = "alert-triage${local.suffix}"
  sop_threat_hunt_name  = "threat-hunt${local.suffix}"

  aws_integration_name    = "${local.module_prefix}-aws${local.suffix}"
  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  slack_integration_name  = "${local.module_prefix}-slack${local.suffix}"

  provision_aws    = trimspace(var.aws_secret_id) != "" && trimspace(var.existing_aws_integration_name) == ""
  provision_github = trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) == ""
  provision_slack  = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""

  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_splunk_integration_name = trimspace(var.existing_splunk_integration_name)
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

# =============================================================================
# Enterprise SOC Analyst AI Agent Module
# =============================================================================

resource "sg_agent" "soc_analyst" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/soc-analyst.md")
  model_names = compact(var.model_names)

  hitl = { always_allowed = ["web_search", "note", "read_notes", "query_logs"] }

  integrations = compact([
    local.resolved_aws_integration_name,
    local.resolved_github_integration_name,
    local.resolved_slack_integration_name,
    local.resolved_splunk_integration_name,
  ])
}

resource "sg_agent_budget" "soc_analyst_budget" {
  agent_name  = sg_agent.soc_analyst.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "read_only" {
  count      = lookup(var.policy_ids, "read_only", "") != "" ? 1 : 0
  agent_name = sg_agent.soc_analyst.name
  policy_id  = var.policy_ids.read_only
  enabled    = true
}

# --- Runbooks ---

resource "sg_runbook_sop" "alert_triage" {
  name        = local.sop_alert_triage_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/alert-triage.md", {}))
}

resource "sg_runbook_sop" "threat_hunt" {
  name        = local.sop_threat_hunt_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/threat-hunt.md", {}))
}

# --- Workflows ---

resource "sg_workflow" "soc_alert_triage" {
  name        = local.workflow_triage_name
  domain      = "secops"
  description = trimspace(templatefile("${path.module}/templates/workflow-alert-triage.md", {}))
  approve     = true

  example_queries = [
    "Triage the new GuardDuty alert regarding unusual IAM API activity in AWS Account Prod.",
    "Investigate the multiple failed SSH login attempts on the bastion host.",
    "Enrich this Okta impossible travel alert and determine if it's a false positive.",
  ]

  stages = [
    { stage_id = "extract-ioc", description = "Extract Indicators of Compromise from the alert payload.", required = true },
    { stage_id = "enrich-context", description = "Enrich IPs and Hashes against Threat Intel.", required = true },
    { stage_id = "log-correlation", description = "Correlate with recent application and infrastructure logs.", required = true },
    { stage_id = "triage-decision", description = "Classify as True Positive or False Positive and draft summary.", required = true },
  ]

  stage_bindings = [
    { stage_id = "extract-ioc", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.alert_triage.name], skill_refs = concat(["soc-ioc-extraction"], try(var.workflow_skill_refs["soc-alert-triage::extract-ioc"], [])) },
    { stage_id = "enrich-context", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.alert_triage.name], skill_refs = concat(["soc-threat-intel-enrichment"], try(var.workflow_skill_refs["soc-alert-triage::enrich-context"], [])) },
    { stage_id = "log-correlation", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.alert_triage.name], skill_refs = concat(["soc-log-correlation"], try(var.workflow_skill_refs["soc-alert-triage::log-correlation"], [])) },
    { stage_id = "triage-decision", agent_ref = sg_agent.soc_analyst.name, stage_depends_on = ["extract-ioc", "enrich-context", "log-correlation"], skill_refs = concat(["soc-alert-disposition"], try(var.workflow_skill_refs["soc-alert-triage::triage-decision"], [])) },
  ]
}

resource "sg_workflow" "soc_threat_hunt" {
  name        = local.workflow_hunt_name
  domain      = "secops"
  description = trimspace(templatefile("${path.module}/templates/workflow-threat-hunt.md", {}))
  approve     = true

  example_queries = [
    "Run a threat hunt for recent CVE-2026-1234 exploitation attempts across our environment.",
    "Hunt for anomalous S3 bucket enumerations from internal EC2 instances.",
    "Check for persistence mechanisms added to any IAM roles in the last 7 days.",
  ]

  stages = [
    { stage_id = "hypothesis", description = "Formulate a threat hunt hypothesis based on intel.", required = true },
    { stage_id = "execute-queries", description = "Query logs to identify patterns matching the hypothesis.", required = true },
    { stage_id = "analyze-findings", description = "Analyze findings for malicious intent.", required = true },
    { stage_id = "generate-report", description = "Produce a final threat hunting report.", required = true },
  ]

  stage_bindings = [
    { stage_id = "hypothesis", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.threat_hunt.name], skill_refs = concat(["soc-threat-hunt-hypothesis"], try(var.workflow_skill_refs["soc-threat-hunt::hypothesis"], [])) },
    { stage_id = "execute-queries", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.threat_hunt.name], skill_refs = concat(["soc-siem-hunt-queries"], try(var.workflow_skill_refs["soc-threat-hunt::execute-queries"], [])) },
    { stage_id = "analyze-findings", agent_ref = sg_agent.soc_analyst.name, stage_depends_on = ["execute-queries"], skill_refs = concat(["soc-malware-analysis"], try(var.workflow_skill_refs["soc-threat-hunt::analyze-findings"], [])) },
    { stage_id = "generate-report", agent_ref = sg_agent.soc_analyst.name, stage_depends_on = ["analyze-findings"], skill_refs = concat(["soc-hunt-reporting"], try(var.workflow_skill_refs["soc-threat-hunt::generate-report"], [])) },
  ]
}
