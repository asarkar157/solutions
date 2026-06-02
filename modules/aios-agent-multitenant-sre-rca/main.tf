terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.21, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "multitenant-sre-rca"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_alert_ingest_name = "datadog-alert-ingest${local.suffix}"
  agent_investigator_name = "rca-investigator${local.suffix}"
  agent_publisher_name    = "rca-publisher${local.suffix}"
  agent_collaborator_name = "rca-collaborator${local.suffix}"

  workflow_rca_name           = "datadog-multitenant-rca${local.suffix}"
  workflow_collaboration_name = "datadog-rca-collaboration${local.suffix}"
  webhook_datadog_name        = "datadog-alert-receiver${local.suffix}"
  webhook_slack_name          = "slack-rca-thread${local.suffix}"

  sop_normalize_name     = "multitenant-rca-alert-normalization${local.suffix}"
  sop_investigate_name   = "multitenant-rca-cross-signal-investigation${local.suffix}"
  sop_synthesize_name    = "multitenant-rca-synthesize-rca${local.suffix}"
  sop_publish_name       = "multitenant-rca-publish-slack${local.suffix}"
  sop_collaboration_name = "multitenant-rca-collaboration${local.suffix}"

  evidence_name = "multitenant-rca${local.suffix}"

  datadog_integration_name = "${local.module_prefix}-datadog${local.suffix}"
  gcp_integration_name     = "${local.module_prefix}-gcp${local.suffix}"
  aws_integration_name     = "${local.module_prefix}-aws${local.suffix}"
  github_integration_name  = "${local.module_prefix}-github${local.suffix}"
  slack_integration_name   = "${local.module_prefix}-slack${local.suffix}"
  ubuntu_integration_name  = "${local.module_prefix}-ubuntu${local.suffix}"
  sop_cce_incident_scope   = "cce-incident-scoping${local.suffix}"

  provision_datadog = (
    (trimspace(var.datadog_api_key) != "" || trimspace(var.datadog_secret_id) != "")
    && trimspace(var.existing_datadog_integration_name) == ""
  )
  provision_gcp = (
    (
      trimspace(var.gcp_secret_id) != ""
      || (trimspace(var.gcp_credentials_json) != "" && trimspace(var.gcp_project_id) != "")
    )
    && trimspace(var.existing_gcp_integration_name) == ""
  )
  provision_aws = (
    trimspace(var.aws_secret_id) != ""
    && trimspace(var.existing_aws_integration_name) == ""
  )
  provision_github = (
    (trimspace(var.github_token) != "" || trimspace(var.github_secret_id) != "")
    && trimspace(var.existing_github_integration_name) == ""
  )
  provision_slack = (
    (trimspace(var.slack_bot_token) != "" || trimspace(var.slack_secret_id) != "")
    && trimspace(var.existing_slack_integration_name) == ""
  )
  provision_ubuntu_cce = var.enable_cce && trimspace(var.existing_ubuntu_integration_name) == "" && (
    trimspace(var.github_token) != "" || trimspace(var.github_secret_id) != "" || trimspace(var.existing_github_integration_name) != ""
  )

  resolved_datadog_integration_name = trimspace(var.existing_datadog_integration_name) != "" ? var.existing_datadog_integration_name : (
    local.provision_datadog ? module.datadog_integration[0].integration_name : ""
  )
  resolved_gcp_integration_name = trimspace(var.existing_gcp_integration_name) != "" ? var.existing_gcp_integration_name : (
    local.provision_gcp ? module.gcp_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_ubuntu_integration_name = trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : (
    local.provision_ubuntu_cce ? module.ubuntu_integration[0].integration_name : ""
  )

  priorities_rego_literals       = join(", ", [for p in var.alert_ingest_allowed_priorities : format("%q", lower(p))])
  tenant_ids_rego_literals       = join(", ", [for t in var.alert_ingest_allowed_tenant_ids : format("%q", lower(t))])
  blocked_services_rego_literals = join(", ", [for s in var.alert_ingest_blocked_services : format("%q", lower(s))])

  alert_ingest_filter_rego = trimspace(templatefile("${path.module}/templates/alert-ingest-filter.rego.tftpl", {
    priorities_gate_enabled        = length(var.alert_ingest_allowed_priorities) > 0
    priorities_rego_literals       = local.priorities_rego_literals
    tenant_ids_gate_enabled        = length(var.alert_ingest_allowed_tenant_ids) > 0
    tenant_ids_rego_literals       = local.tenant_ids_rego_literals
    tenant_tag_key                 = var.tenant_tag_key
    blocked_gate_enabled           = length(var.alert_ingest_blocked_services) > 0
    blocked_services_rego_literals = local.blocked_services_rego_literals
  }))

  investigation_template_vars = {
    tenant_tag_key                   = var.tenant_tag_key
    gcp_project_id                   = var.gcp_project_id
    gcp_region                       = var.gcp_region
    github_default_org               = var.github_default_org
    github_default_repos             = jsonencode(var.github_default_repos)
    aws_ecs_cluster_hints            = jsonencode(var.aws_ecs_cluster_hints)
    slack_rca_channel                = var.slack_rca_channel
    slack_collaboration_channel_hint = var.slack_collaboration_channel_hint
  }

  attach_policy = {
    data_risk_pii = try(var.policy_create_flags.data_risk_pii, false)
  }
}

# =============================================================================
# Integration submodules
# =============================================================================

module "datadog_integration" {
  count  = local.provision_datadog ? 1 : 0
  source = "../aios-integration-datadog"

  integration_name   = local.datadog_integration_name
  datadog_api_key    = var.datadog_api_key
  datadog_app_key    = var.datadog_app_key
  datadog_site       = var.datadog_site
  existing_secret_id = var.datadog_secret_id
  description        = "Datadog integration owned by ${local.agent_investigator_name} (multi-tenant RCA investigation)."
}

module "gcp_integration" {
  count  = local.provision_gcp ? 1 : 0
  source = "../aios-integration-gcp"

  integration_name     = local.gcp_integration_name
  gcp_credentials_json = var.gcp_credentials_json
  gcp_project_id       = var.gcp_project_id
  gcp_region           = var.gcp_region
  existing_secret_id   = var.gcp_secret_id
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
  description        = "AWS integration owned by ${local.agent_investigator_name} (ECS deploy history and CloudTrail RCA)."
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  github_token       = var.github_token
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by ${local.agent_investigator_name} (commit history and blame for RCA)."
}

module "cce_scripts" {
  count  = var.enable_cce ? 1 : 0
  source = "../aios-cce-scripts"
}

module "ubuntu_integration" {
  count  = local.provision_ubuntu_cce ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = compact([var.github_secret_id])
  install_tools    = ["gh", "git", "curl", "jq", "cce"]
  env_vars = {
    CCE_PACK_VERSION = module.cce_scripts[0].cce_pack_version
    CCE_PACK_DIR     = module.cce_scripts[0].cce_pack_dir
    CCE_PACK_B64     = module.cce_scripts[0].cce_pack_tarball_b64
    CCE_USE_CASE     = "incident-scoping"
  }
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name     = local.slack_integration_name
  slack_bot_token      = var.slack_bot_token
  slack_signing_secret = var.slack_signing_secret
  slack_webhook_url    = var.slack_webhook_url
  existing_secret_id   = var.slack_secret_id
  description          = "Slack integration owned by ${local.agent_publisher_name} (RCA publish and thread collaboration)."
}

resource "terraform_data" "datadog_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_datadog_integration_name) != ""
      error_message = "aios-agent-multitenant-sre-rca needs a Datadog Guild integration: provide inline credentials, `datadog_secret_id`, or `existing_datadog_integration_name`."
    }
  }
}

resource "terraform_data" "gcp_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_gcp_integration_name) != ""
      error_message = "aios-agent-multitenant-sre-rca needs a GCP Guild integration: provide `gcp_secret_id`, inline credentials + `gcp_project_id`, or `existing_gcp_integration_name`."
    }
  }
}

resource "terraform_data" "aws_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_aws_integration_name) != ""
      error_message = "aios-agent-multitenant-sre-rca needs an AWS Guild integration: provide `aws_secret_id` (the module provisions one) or `existing_aws_integration_name`."
    }
  }
}

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aios-agent-multitenant-sre-rca needs a GitHub Guild integration: provide `github_token`/`github_secret_id`, or `existing_github_integration_name`."
    }
  }
}

resource "terraform_data" "slack_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_slack_integration_name) != ""
      error_message = "aios-agent-multitenant-sre-rca needs a Slack Guild integration: provide `slack_bot_token`/`slack_secret_id`, or `existing_slack_integration_name`."
    }
  }
}

# =============================================================================
# Agents
# =============================================================================

resource "sg_agent" "datadog_alert_ingest" {
  name        = local.agent_alert_ingest_name
  persona     = file("${path.module}/personas/datadog-alert-ingest.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_datadog_integration_name,
    local.resolved_slack_integration_name,
  ])
}

resource "sg_agent" "rca_investigator" {
  name        = local.agent_investigator_name
  persona     = file("${path.module}/personas/rca-investigator.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_datadog_integration_name,
    local.resolved_gcp_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_github_integration_name,
    local.resolved_ubuntu_integration_name,
  ])
}

resource "sg_agent" "rca_publisher" {
  name        = local.agent_publisher_name
  persona     = file("${path.module}/personas/rca-publisher.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_slack_integration_name,
  ])
}

resource "sg_agent" "rca_collaborator" {
  name        = local.agent_collaborator_name
  persona     = file("${path.module}/personas/rca-collaborator.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_datadog_integration_name,
    local.resolved_gcp_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_github_integration_name,
    local.resolved_slack_integration_name,
  ])
}

# =============================================================================
# Agent budgets
# =============================================================================

resource "sg_agent_budget" "datadog_alert_ingest" {
  agent_name  = sg_agent.datadog_alert_ingest.name
  limit_usd   = var.agent_budgets.alert_ingest
  period_type = "daily"
}

resource "sg_agent_budget" "rca_investigator" {
  agent_name  = sg_agent.rca_investigator.name
  limit_usd   = var.agent_budgets.investigator
  period_type = "daily"
}

resource "sg_agent_budget" "rca_publisher" {
  agent_name  = sg_agent.rca_publisher.name
  limit_usd   = var.agent_budgets.publisher
  period_type = "daily"
}

resource "sg_agent_budget" "rca_collaborator" {
  agent_name  = sg_agent.rca_collaborator.name
  limit_usd   = var.agent_budgets.collaborator
  period_type = "daily"
}

# =============================================================================
# Policy attachments
# =============================================================================

resource "sg_agent_policy_attachment" "datadog_alert_ingest_dangerous_ops" {
  agent_name = sg_agent.datadog_alert_ingest.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "rca_investigator_dangerous_ops" {
  agent_name = sg_agent.rca_investigator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "rca_publisher_dangerous_ops" {
  agent_name = sg_agent.rca_publisher.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "rca_collaborator_dangerous_ops" {
  agent_name = sg_agent.rca_collaborator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "datadog_alert_ingest_data_risk_pii" {
  count      = local.attach_policy.data_risk_pii ? 1 : 0
  agent_name = sg_agent.datadog_alert_ingest.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_agent_policy_attachment" "rca_investigator_data_risk_pii" {
  count      = local.attach_policy.data_risk_pii ? 1 : 0
  agent_name = sg_agent.rca_investigator.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_agent_policy_attachment" "rca_publisher_data_risk_pii" {
  count      = local.attach_policy.data_risk_pii ? 1 : 0
  agent_name = sg_agent.rca_publisher.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_agent_policy_attachment" "rca_collaborator_data_risk_pii" {
  count      = local.attach_policy.data_risk_pii ? 1 : 0
  agent_name = sg_agent.rca_collaborator.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

# =============================================================================
# Runbooks
# =============================================================================

resource "sg_runbook_sop" "alert_normalization" {
  name        = local.sop_normalize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-alert-normalization.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "cross_signal_investigation" {
  name        = local.sop_investigate_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-cross-signal-investigation.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "cce_incident_scoping" {
  count       = var.enable_cce ? 1 : 0
  name        = local.sop_cce_incident_scope
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cce-incident-scoping.md.tftpl", local.investigation_template_vars))
}

resource "sg_runbook_sop" "synthesize_rca" {
  name        = local.sop_synthesize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-synthesize-rca.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "publish_rca_slack" {
  name        = local.sop_publish_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-publish-rca-slack.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "rca_collaboration" {
  name        = local.sop_collaboration_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-rca-collaboration.md", local.investigation_template_vars))
}

# =============================================================================
# Evidence checklist
# =============================================================================

resource "sg_evidence_checklist" "multitenant_rca" {
  count       = var.enable_evidence_checklist ? 1 : 0
  name        = local.evidence_name
  description = "Proof-of-work for multi-tenant Datadog RCA: monitor linkage, timeline, root cause, and tenant scope before Slack publish."
  approve     = true
  required_items = [
    "datadog_monitor_linked",
    "timeline_documented",
    "root_cause_stated",
    "tenant_scope_identified",
  ]
  scoring = {
    min_required         = 4
    confidence_threshold = 0.70
  }
  metadata = { playbook = "datadog-multitenant-rca" }
}

# =============================================================================
# Workflow — Datadog multi-tenant RCA
# =============================================================================

resource "sg_workflow" "datadog_multitenant_rca" {
  name        = local.workflow_rca_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-datadog-multitenant-rca.md", local.investigation_template_vars))
  approve     = true

  evidence_checklist_ref = var.enable_evidence_checklist ? sg_evidence_checklist.multitenant_rca[0].name : null

  metadata = {
    planner_max_tool_iterations = 45
  }

  triggers = [
    { field = "source", values = ["datadog"], type = "active", source = "datadog" },
    { field = "incident_title_contains", values = ["alert", "monitor", "tenant", "error"], type = "passive" },
  ]

  required_inputs = ["alert_id"]
  optional_inputs = ["monitor_id", "tenant_id", "service", "priority"]

  runbook_refs = [
    sg_runbook_sop.alert_normalization.name,
    sg_runbook_sop.cross_signal_investigation.name,
    sg_runbook_sop.synthesize_rca.name,
    sg_runbook_sop.publish_rca_slack.name,
  ]

  example_queries = [
    "Datadog P2 on tenant acme-prod — cross-signal RCA with GCP logs and ECS deploy history",
    "High error rate alert for checkout-api — investigate CloudTrail changes and recent GitHub commits",
    "Multi-tenant latency spike — produce RCA and post to #sre-rca",
  ]

  stages = [
    { stage_id = "alert-ingest-filter", description = "Deterministic Rego filter on raw Datadog webhook payload (priority, tenant_id allowlist, blocked services/tags).", required = true },
    { stage_id = "normalize-alert", description = "Parse Datadog alert, extract tenant_id from tags, emit normalized_alert JSON.", required = true },
    { stage_id = "cross-signal-investigate", description = "Read-only cross-signal analysis: Datadog metrics, GCP Cloud Logging, AWS ECS deploy history, CloudTrail, GitHub commits.", required = true },
    { stage_id = "synthesize-rca", description = "Produce structured RCA markdown JSON: summary, timeline, root_cause, evidence_links, tenant_impact.", required = true },
    { stage_id = "publish-rca-slack", description = "Format and post RCA summary to Slack channel/thread.", required = true },
  ]

  stage_bindings = [
    {
      stage_id    = "alert-ingest-filter"
      action_type = "policy_check"
      action_config = {
        inline_rego = local.alert_ingest_filter_rego
      }
    },
    {
      stage_id         = "normalize-alert"
      agent_ref        = sg_agent.datadog_alert_ingest.name
      stage_depends_on = ["alert-ingest-filter"]
      runbook_refs     = [sg_runbook_sop.alert_normalization.name]
      skill_refs       = concat(["mtsre-datadog-alert-normalize"], try(var.workflow_skill_refs["datadog-multitenant-rca::normalize-alert"], []))
      note             = "Normalize inbound Datadog alert and extract tenant scope from tags."
    },
    {
      stage_id         = "cross-signal-investigate"
      agent_ref        = sg_agent.rca_investigator.name
      stage_depends_on = ["normalize-alert"]
      runbook_refs = compact(concat(
        [sg_runbook_sop.cross_signal_investigation.name],
        var.enable_cce ? [sg_runbook_sop.cce_incident_scoping[0].name] : [],
      ))
      skill_refs = concat(
        ["mtsre-cross-signal-investigation"],
        var.enable_cce ? [local.sop_cce_incident_scope] : [],
        try(var.workflow_skill_refs["datadog-multitenant-rca::cross-signal-investigate"], []),
      )
      note = "Cross-signal investigation using Datadog, GCP, AWS, GitHub, and optional Ubuntu CCE incident scoping."
    },
    {
      stage_id         = "synthesize-rca"
      agent_ref        = sg_agent.rca_investigator.name
      stage_depends_on = ["cross-signal-investigate"]
      runbook_refs     = [sg_runbook_sop.synthesize_rca.name]
      skill_refs       = concat(["mtsre-rca-synthesis"], try(var.workflow_skill_refs["datadog-multitenant-rca::synthesize-rca"], []))
      note             = "Synthesize structured RCA JSON from investigation evidence."
    },
    {
      stage_id         = "publish-rca-slack"
      agent_ref        = sg_agent.rca_publisher.name
      stage_depends_on = ["synthesize-rca"]
      runbook_refs     = [sg_runbook_sop.publish_rca_slack.name]
      skill_refs       = concat(["mtsre-slack-rca-publish"], try(var.workflow_skill_refs["datadog-multitenant-rca::publish-rca-slack"], []))
      note             = "Post formatted RCA to Slack channel with investigation_id for thread follow-up."
    },
  ]
}

# =============================================================================
# Workflow — Datadog RCA collaboration (thread follow-up)
# =============================================================================

resource "sg_workflow" "datadog_rca_collaboration" {
  name        = local.workflow_collaboration_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-datadog-rca-collaboration.md", local.investigation_template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = 30
  }

  triggers = [
    { field = "source", values = ["slack"], type = "active", source = "slack" },
    { field = "incident_title_contains", values = ["rca", "follow-up", "investigation"], type = "passive" },
  ]

  required_inputs = ["tenant_id", "investigation_id"]
  optional_inputs = ["parent_workflow_ref", "slack_thread_ts", "user_question"]

  runbook_refs = [
    sg_runbook_sop.rca_collaboration.name,
  ]

  example_queries = [
    "Follow up on investigation inv-abc123 for tenant acme-prod — was the ECS deploy the root cause?",
    "Continue RCA thread: show CloudTrail events around the deploy window",
    "Answer in Slack thread: which GitHub commit introduced the regression?",
  ]

  stages = [
    { stage_id = "collaborate", description = "Answer follow-up questions in Slack thread context using prior investigation notes; read-only unless user requests re-investigation.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "collaborate"
      agent_ref    = sg_agent.rca_collaborator.name
      runbook_refs = [sg_runbook_sop.rca_collaboration.name]
      skill_refs   = concat(["mtsre-rca-thread-collaborate"], try(var.workflow_skill_refs["datadog-rca-collaboration::collaborate"], []))
      note         = "Thread-aware collaboration on completed RCA investigations."
    },
  ]
}

# =============================================================================
# Webhook ingress
# =============================================================================

resource "sg_webhook" "datadog_alert_receiver" {
  count = var.enable_datadog_webhook ? 1 : 0

  name          = local.webhook_datadog_name
  target_type   = "workflow"
  target_name   = sg_workflow.datadog_multitenant_rca.name
  action        = "A Datadog monitor alert fired for a multi-tenant SaaS workload. Parse the webhook JSON, apply ingest filters, extract tenant_id from tags, run cross-signal RCA across Datadog/GCP/AWS/GitHub, and publish the summary to Slack."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}

resource "sg_webhook" "slack_rca_thread" {
  count = var.enable_slack_collaboration_webhook ? 1 : 0

  name          = local.webhook_slack_name
  target_type   = "workflow"
  target_name   = sg_workflow.datadog_rca_collaboration.name
  action        = "A user continued the investigation in a Slack thread. Load the prior RCA context by investigation_id and tenant_id, answer the follow-up question in thread context, and fetch additional read-only evidence only when needed — do not re-run the full RCA unless explicitly requested."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
