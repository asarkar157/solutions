terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.19, < 0.2.0" }
  }
}

locals {
  module_prefix = "predictive-sre"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_predictive_analyst_name   = "predictive-analyst${local.suffix}"
  workflow_predictive_name        = "predictive-incident-triage${local.suffix}"
  sop_cross_domain_name           = "cross-domain-correlation${local.suffix}"
  sop_predictive_degradation_name = "predictive-degradation-analysis${local.suffix}"

  github_integration_name  = "${local.module_prefix}-github${local.suffix}"
  grafana_integration_name = "${local.module_prefix}-grafana${local.suffix}"
  aws_integration_name     = "${local.module_prefix}-aws${local.suffix}"
  slack_integration_name   = "${local.module_prefix}-slack${local.suffix}"

  provision_github  = trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) == ""
  provision_grafana = trimspace(var.grafana_secret_id) != "" && trimspace(var.existing_grafana_integration_name) == ""
  provision_aws     = trimspace(var.aws_secret_id) != "" && trimspace(var.existing_aws_integration_name) == ""
  provision_slack   = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_grafana_integration_name = trimspace(var.existing_grafana_integration_name) != "" ? var.existing_grafana_integration_name : (
    local.provision_grafana ? module.grafana_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
}

module "grafana_integration" {
  count  = local.provision_grafana ? 1 : 0
  source = "../aios-integration-grafana"

  integration_name   = local.grafana_integration_name
  existing_secret_id = var.grafana_secret_id
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

# =============================================================================
# Predictive SRE Agent Module
# =============================================================================

resource "sg_agent" "predictive_analyst" {
  name        = local.agent_predictive_analyst_name
  persona     = file("${path.module}/personas/predictive-analyst.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_grafana_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_slack_integration_name,
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
  name        = local.sop_cross_domain_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cross-domain-correlation.md", {}))
}

resource "sg_runbook_sop" "predictive_degradation" {
  name        = local.sop_predictive_degradation_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/predictive-degradation-analysis.md", {}))
}

resource "sg_workflow" "predictive_triage" {
  name        = local.workflow_predictive_name
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
