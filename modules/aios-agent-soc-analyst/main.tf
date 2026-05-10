terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.8, < 0.2.0" }
  }
}

# =============================================================================
# Enterprise SOC Analyst AI Agent Module
# =============================================================================

resource "sg_agent" "soc_analyst" {
  name    = "soc-analyst"
  persona = file("${path.module}/personas/soc-analyst.md")
  model_names = compact([
    lookup(var.model_names, "gpt4o", ""),
    lookup(var.model_names, "claude_sonnet", ""),
    lookup(var.model_names, "gemini_flash", "")
  ])

  hitl = { always_allowed = ["web_search", "note", "read_notes", "query_logs"] }

  integrations = compact([
    lookup(var.integration_names, "aws", "") != "" ? var.integration_names.aws : null,
    lookup(var.integration_names, "github", "") != "" ? var.integration_names.github : null,
    lookup(var.integration_names, "slack", "") != "" ? var.integration_names.slack : null,
    lookup(var.integration_names, "splunk", "") != "" ? var.integration_names.splunk : null,
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
  name        = "alert-triage"
  description = trimspace(templatefile("${path.module}/templates/alert-triage.md", {}))
}

resource "sg_runbook_sop" "threat_hunt" {
  name        = "threat-hunt"
  description = trimspace(templatefile("${path.module}/templates/threat-hunt.md", {}))
}

# --- Workflows ---

resource "sg_workflow" "soc_alert_triage" {
  name        = "soc-alert-triage"
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
    { stage_id = "extract-ioc", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.alert_triage.name] },
    { stage_id = "enrich-context", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.alert_triage.name] },
    { stage_id = "log-correlation", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.alert_triage.name] },
    { stage_id = "triage-decision", agent_ref = sg_agent.soc_analyst.name, stage_depends_on = ["extract-ioc", "enrich-context", "log-correlation"] },
  ]
}

resource "sg_workflow" "soc_threat_hunt" {
  name        = "soc-threat-hunt"
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
    { stage_id = "hypothesis", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.threat_hunt.name] },
    { stage_id = "execute-queries", agent_ref = sg_agent.soc_analyst.name, runbook_refs = [sg_runbook_sop.threat_hunt.name] },
    { stage_id = "analyze-findings", agent_ref = sg_agent.soc_analyst.name, stage_depends_on = ["execute-queries"] },
    { stage_id = "generate-report", agent_ref = sg_agent.soc_analyst.name, stage_depends_on = ["analyze-findings"] },
  ]
}
