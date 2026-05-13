terraform {
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

# ============================================================================
# Alert Triage Coordinator Agent
# ============================================================================

resource "sg_agent" "alert_triage_coordinator" {
  name        = "alert-triage-coordinator"
  persona     = "You are an SRE Coordinator responsible for receiving Grafana alerts and orchestrating root cause analysis across AWS, Azure, K8s, and Remote Runner platforms. You dynamically identify the affected system based on alert labels and delegate investigative tasks to the best-fit agent."
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  # Integrates with Grafana to pull the initial alert data and Slack for notifications
  integrations = compact([
    var.integration_names.grafana,
    var.integration_names.slack
  ])
}

resource "sg_agent_policy_attachment" "coordinator_dangerous_ops" {
  agent_name = sg_agent.alert_triage_coordinator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# ============================================================================
# Runbook SOPs (Skill definitions)
# ============================================================================

resource "sg_runbook_sop" "grafana_alert_routing" {
  name        = "grafana-alert-routing-sop"
  approve     = true
  description = <<-EOT
    Triages an incoming Grafana alert by checking the datasource and routing to the correct cloud provider skill.
    
    Steps:
    1) Extract the alert UID and evaluate the active instances.
    2) Check the labels and annotations to determine the target environment (e.g., AWS, Azure, K8s).
    3) Summarize the symptom and the affected system component.
    4) Ensure the context is fully prepped so the dynamically resolved cloud agent can perform a deep dive on the infrastructure.
  EOT
}

# ============================================================================
# Workflow (Cross-Platform Alert Triage Pipeline)
# ============================================================================

resource "sg_workflow" "alert_triage_pipeline" {
  name        = "cross-platform-alert-triage"
  domain      = "incident-response"
  description = "A workflow that automatically triages incoming Grafana alerts against AWS, Azure, K8s, or Remote Runner environments using dynamic agent resolution based on skill matching."
  approve     = true

  triggers = [
    { field = "source", values = ["grafana"], type = "active", source = "grafana" }
  ]

  required_inputs = ["alert_uid"]

  runbook_refs = [
    sg_runbook_sop.grafana_alert_routing.name
  ]

  stages = [
    {
      stage_id    = "alert-extraction"
      description = "Extract the alert details from the Grafana datasource to understand what is firing."
      note        = "Use the Grafana integration to read the alert rule and its firing instances. Summarize the environment labels."
      required    = true
    },
    {
      stage_id    = "cloud-triage"
      description = "Triage the issue against AWS, Azure, K8s, or Remote Runner based on the alert labels."
      note        = "Dynamically resolve to the best-fit agent (AWS SRE, Azure DevOps, or Ubuntu CLI) to investigate the underlying infrastructure failure. Use the context from the alert extraction stage."
      required    = true
    },
    {
      stage_id    = "notify-slack"
      description = "Post the triage findings and recommended remediation to Slack."
      note        = "Use the slack integration to inform the team with the findings from the cloud-triage stage."
      required    = true
    }
  ]

  stage_bindings = [
    {
      stage_id   = "alert-extraction"
      agent_ref  = sg_agent.alert_triage_coordinator.name
      skill_refs = concat(["sre-grafana-alert-ingest", "sre-alert-normalization"], try(var.workflow_skill_refs["cross-platform-alert-triage::alert-extraction"], []))
      note       = "Driven by the Coordinator to fetch the alert from Grafana."
    },
    {
      stage_id         = "cloud-triage"
      stage_depends_on = ["alert-extraction"]
      skill_refs       = concat(["sre-multi-cloud-triage", "sre-dynamic-agent-routing"], try(var.workflow_skill_refs["cross-platform-alert-triage::cloud-triage"], []))
      note             = "The runtime will automatically resolve the best-fit agent (e.g., AWS SRE for AWS issues, Azure DevOps for Azure issues, or Ubuntu CLI) based on skill and integration matching."
    },
    {
      stage_id         = "notify-slack"
      agent_ref        = sg_agent.alert_triage_coordinator.name
      stage_depends_on = ["cloud-triage"]
      skill_refs       = concat(["sre-slack-incident-summary"], try(var.workflow_skill_refs["cross-platform-alert-triage::notify-slack"], []))
      note             = "Post the compiled report to the Slack channel."
    }
  ]
}

# ============================================================================
# Webhook Ingress
# ============================================================================

resource "sg_webhook" "grafana_alerts" {
  name        = "grafana-alert-receiver"
  target_type = "workflow"
  target_name = sg_workflow.alert_triage_pipeline.name
  action      = "A new Grafana alert has fired. Triage the incoming JSON payload, extract the alert UID and labels, and determine the root cause."
  enabled     = true
}
