terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.17, < 0.2.0" }
  }
}

# =============================================================================
# Predictive SRE Agent Module
# =============================================================================

resource "sg_agent" "predictive_analyst" {
  name        = "predictive-analyst"
  persona     = file("${path.module}/personas/predictive-analyst.md")
  model_names = compact(var.model_names)

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
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cross-domain-correlation.md", {}))
}

resource "sg_runbook_sop" "predictive_degradation" {
  name        = "predictive-degradation-analysis"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/predictive-degradation-analysis.md", {}))
}

resource "sg_workflow" "predictive_triage" {
  name        = "predictive-incident-triage"
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-predictive-incident-triage.md", {}))
  approve     = true

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
    { stage_id = "code-context", agent_ref = var.agent_names.github_agent, skill_refs = concat(["sre-github-deploy-context"], try(var.workflow_skill_refs["predictive-incident-triage::code-context"], [])) },
    { stage_id = "metrics-context", agent_ref = var.agent_names.grafana_agent, skill_refs = concat(["sre-grafana-metrics-context"], try(var.workflow_skill_refs["predictive-incident-triage::metrics-context"], [])) },
    { stage_id = "infrastructure-context", agent_ref = var.agent_names.aws_agent, skill_refs = concat(["sre-aws-infra-context"], try(var.workflow_skill_refs["predictive-incident-triage::infrastructure-context"], [])) },
    { stage_id = "predictive-synergy", agent_ref = sg_agent.predictive_analyst.name, stage_depends_on = ["code-context", "metrics-context", "infrastructure-context"], runbook_refs = [sg_runbook_sop.cross_domain_correlation.name, sg_runbook_sop.predictive_degradation.name], skill_refs = concat(["sre-predictive-correlation", "sre-degradation-forecast"], try(var.workflow_skill_refs["predictive-incident-triage::predictive-synergy"], [])) },
  ]
}
