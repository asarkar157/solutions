terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.0" }
  }
}

# =============================================================================
# Predictive SRE Agent Module
# =============================================================================

resource "sg_agent" "predictive_analyst" {
  name        = "predictive-analyst"
  persona     = file("${path.module}/personas/predictive-analyst.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  integrations = compact([
    lookup(var.integration_names, "github", "") != "" ? var.integration_names.github : null,
    lookup(var.integration_names, "grafana", "") != "" ? var.integration_names.grafana : null,
    lookup(var.integration_names, "aws", "") != "" ? var.integration_names.aws : null,
    lookup(var.integration_names, "slack", "") != "" ? var.integration_names.slack : null,
  ])
}

resource "sg_agent_budget" "predictive_analyst" {
  agent_name  = sg_agent.predictive_analyst.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.predictive_analyst.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_runbook_sop" "cross_domain_correlation" {
  name        = "cross-domain-correlation"
  description = "Correlate GitHub deployments, AWS K8s stability, and Grafana trends. Steps: 1) Query Grafana, 2) Query GitHub PRs, 3) Check K8s, 4) Synthesize timeline."
}

resource "sg_runbook_sop" "predictive_degradation" {
  name        = "predictive-degradation-analysis"
  description = "Predict infrastructure failures. Steps: 1) Read 72h CPU/Memory trends, 2) Map slope, 3) Determine limits, 4) Calculate TTF, 5) Correlate, 6) Recommend."
}

resource "sg_workflow" "predictive_triage" {
  name        = "predictive-incident-triage"
  domain      = "incident-response"
  description = "Cross-domain predictive triage: code context, metrics context, infrastructure context, and predictive synthesis."

  triggers        = [{ field = "incident_title_contains", values = ["degradation", "OOM", "latency creep", "memory leak"], type = "passive" }]
  required_inputs = ["service_name"]
  optional_inputs = ["incident_timestamp"]
  runbook_refs    = [sg_runbook_sop.cross_domain_correlation.name, sg_runbook_sop.predictive_degradation.name]

  example_queries = [
    "Predict when the backend will run out of memory",
    "Correlate latency spikes with yesterday's deploys",
    "Figure out what is wrong across github, k8s, and grafana",
  ]

  stages = [
    { stage_id = "code-context", description = "Fetch recent PRs and deployments.", required = true },
    { stage_id = "metrics-context", description = "Fetch metric trends and alerts.", required = true },
    { stage_id = "infrastructure-context", description = "Check K8s cluster health.", required = true },
    { stage_id = "predictive-synergy", description = "Correlate and predict system behavior.", required = true },
  ]

  stage_bindings = [
    { stage_id = "code-context", agent_ref = var.agent_names.github_agent },
    { stage_id = "metrics-context", agent_ref = var.agent_names.grafana_agent },
    { stage_id = "infrastructure-context", agent_ref = var.agent_names.aws_agent },
    { stage_id = "predictive-synergy", agent_ref = sg_agent.predictive_analyst.name, stage_depends_on = ["code-context", "metrics-context", "infrastructure-context"], runbook_refs = [sg_runbook_sop.cross_domain_correlation.name, sg_runbook_sop.predictive_degradation.name] },
  ]
}
