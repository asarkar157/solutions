terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # sg_remote_runner (>= 0.1.23) when create_remote_runner; sg_webhook updates (>= 0.1.21).
      version = ">= 0.1.23, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "privatesaas-gitops-sre"
  suffix        = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_intake_name       = "slack-sre-intake${local.suffix}"
  agent_investigator_name = "gitops-sre-investigator${local.suffix}"
  agent_remediator_name   = "gitops-sre-remediator${local.suffix}"

  workflow_incident_name = "gitops-sre-incident-response${local.suffix}"
  workflow_audit_name    = "gitops-sre-quality-audit${local.suffix}"
  webhook_name           = "slack-gitops-sre${local.suffix}"

  sop_normalize_name    = "gitops-normalize-slack${local.suffix}"
  sop_gitlab_name       = "gitops-correlate-gitlab${local.suffix}"
  sop_argocd_name       = "gitops-inspect-argocd${local.suffix}"
  sop_dynamodb_name     = "gitops-inspect-dynamodb${local.suffix}"
  sop_containers_name   = "gitops-inspect-containers${local.suffix}"
  sop_sonarqube_name    = "gitops-assess-sonarqube${local.suffix}"
  sop_synthesize_name   = "gitops-synthesize-rca${local.suffix}"
  sop_remediate_name    = "gitops-recommend-notify${local.suffix}"
  sop_gitlab_audit_name = "gitops-gitlab-branch-scan${local.suffix}"
  sop_sonar_audit_name  = "gitops-sonarqube-metrics${local.suffix}"
  sop_dynamo_audit_name = "gitops-dynamodb-capacity${local.suffix}"

  evidence_name = "gitops-sre-rca${local.suffix}"

  gitlab_integration_name    = "${local.module_prefix}-gitlab${local.suffix}"
  argocd_integration_name    = "${local.module_prefix}-argocd${local.suffix}"
  sonarqube_integration_name = "${local.module_prefix}-sonarqube${local.suffix}"
  aws_integration_name       = "${local.module_prefix}-aws${local.suffix}"
  slack_integration_name     = "${local.module_prefix}-slack${local.suffix}"
  ubuntu_integration_name    = "${local.module_prefix}-ubuntu${local.suffix}"

  provision_gitlab = (
    (
      trimspace(var.gitlab_secret_id) != ""
      || (trimspace(var.gitlab_base_url) != "" && trimspace(var.gitlab_private_token) != "")
    )
    && trimspace(var.existing_gitlab_integration_name) == ""
  )
  provision_argocd = (
    (
      trimspace(var.argocd_secret_id) != ""
      || (trimspace(var.argocd_server_url) != "" && trimspace(var.argocd_auth_token) != "")
      || (trimspace(var.argocd_server_url) != "" && trimspace(var.argocd_username) != "" && trimspace(var.argocd_password) != "")
    )
    && trimspace(var.existing_argocd_integration_name) == ""
  )
  provision_sonarqube = (
    (
      trimspace(var.sonarqube_secret_id) != ""
      || (trimspace(var.sonarqube_server_url) != "" && trimspace(var.sonarqube_token) != "")
    )
    && trimspace(var.existing_sonarqube_integration_name) == ""
  )
  provision_aws = (
    trimspace(var.aws_secret_id) != ""
    && trimspace(var.existing_aws_integration_name) == ""
  )
  provision_slack = (
    (
      trimspace(var.slack_bot_token) != ""
      || trimspace(var.slack_secret_id) != ""
    )
    && trimspace(var.existing_slack_integration_name) == ""
  )

  create_ubuntu_integration = (
    var.enable_ubuntu_cli || var.create_remote_runner
  ) && trimspace(var.existing_ubuntu_integration_name) == ""

  resolved_gitlab_integration_name = trimspace(var.existing_gitlab_integration_name) != "" ? var.existing_gitlab_integration_name : (
    local.provision_gitlab ? module.gitlab_integration[0].integration_name : ""
  )
  resolved_argocd_integration_name = trimspace(var.existing_argocd_integration_name) != "" ? var.existing_argocd_integration_name : (
    local.provision_argocd ? module.argocd_integration[0].integration_name : ""
  )
  resolved_sonarqube_integration_name = trimspace(var.existing_sonarqube_integration_name) != "" ? var.existing_sonarqube_integration_name : (
    local.provision_sonarqube ? module.sonarqube_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_ubuntu_integration_name = coalesce(
    trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : null,
    try(module.ubuntu_integration[0].integration_name, null),
    local.create_ubuntu_integration ? local.ubuntu_integration_name : null,
    "",
  )

  investigator_integrations = compact([
    local.resolved_gitlab_integration_name,
    local.resolved_argocd_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_sonarqube_integration_name,
    local.resolved_ubuntu_integration_name != "" ? local.resolved_ubuntu_integration_name : null,
  ])

  remediator_integrations = compact([
    local.resolved_slack_integration_name,
    local.resolved_gitlab_integration_name,
    local.resolved_argocd_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_sonarqube_integration_name,
    local.resolved_ubuntu_integration_name != "" ? local.resolved_ubuntu_integration_name : null,
  ])

  remote_runner_names = (
    var.create_remote_runner
    && var.remote_runner_attach_to_agent
    && length(module.remote_runner) > 0
  ) ? toset([module.remote_runner[0].runner_name]) : null

  channels_rego_literals      = join(", ", [for c in var.slack_channel_allowlist : format("%q", lower(c))])
  environments_rego_literals  = join(", ", [for e in var.slack_ingest_allowed_environment_tags : format("%q", lower(e))])
  blocked_substrings_literals = join(", ", [for b in var.slack_ingest_blocked_substrings : format("%q", lower(b))])

  slack_ingest_filter_rego = trimspace(templatefile("${path.module}/templates/slack-ingest-filter.rego.tftpl", {
    channels_gate_enabled            = length(var.slack_channel_allowlist) > 0
    channels_rego_literals           = local.channels_rego_literals
    environments_gate_enabled        = length(var.slack_ingest_allowed_environment_tags) > 0
    environments_rego_literals       = local.environments_rego_literals
    blocked_gate_enabled             = length(var.slack_ingest_blocked_substrings) > 0
    blocked_substrings_rego_literals = local.blocked_substrings_literals
  }))

  template_vars = {
    private_saas_environment_label = var.private_saas_environment_label
    gitlab_default_project_paths   = jsonencode(var.gitlab_default_project_paths)
    argocd_application_hints       = jsonencode(var.argocd_application_hints)
    dynamodb_table_hints           = jsonencode(var.dynamodb_table_hints)
    sonarqube_project_keys         = jsonencode(var.sonarqube_project_keys)
    slack_notify_channel_hint      = var.slack_notify_channel_hint
  }

  attach_policy = {
    sre_remediation = try(var.policy_create_flags.sre_remediation, true)
    prod_write_gate = try(var.policy_create_flags.prod_write_gate, true)
  }
}

# =============================================================================
# Integrations
# =============================================================================

module "gitlab_integration" {
  count  = local.provision_gitlab ? 1 : 0
  source = "../aios-integration-gitlab"

  integration_name   = local.gitlab_integration_name
  base_url           = var.gitlab_base_url
  private_token      = var.gitlab_private_token
  existing_secret_id = var.gitlab_secret_id
  description        = "GitLab integration for ${local.agent_investigator_name}."
}

module "argocd_integration" {
  count  = local.provision_argocd ? 1 : 0
  source = "../aios-integration-argocd"

  integration_name   = local.argocd_integration_name
  server_url         = var.argocd_server_url
  auth_token         = var.argocd_auth_token
  username           = var.argocd_username
  password           = var.argocd_password
  existing_secret_id = var.argocd_secret_id
  integration_type   = var.argocd_integration_type
  description        = "Argo CD integration for ${local.agent_investigator_name}."
}

module "sonarqube_integration" {
  count  = local.provision_sonarqube ? 1 : 0
  source = "../aios-integration-sonarqube"

  integration_name   = local.sonarqube_integration_name
  server_url         = var.sonarqube_server_url
  token              = var.sonarqube_token
  existing_secret_id = var.sonarqube_secret_id
  description        = "SonarQube integration for ${local.agent_investigator_name}."
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
  description        = "AWS integration for DynamoDB investigation (${local.agent_investigator_name})."
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name     = local.slack_integration_name
  slack_bot_token      = var.slack_bot_token
  slack_signing_secret = var.slack_signing_secret
  slack_webhook_url    = var.slack_webhook_url
  existing_secret_id   = var.slack_secret_id
  description          = "Slack integration for ${local.agent_intake_name} (GitOps SRE intake and notify)."
}

module "ubuntu_integration" {
  count  = local.create_ubuntu_integration ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = var.ubuntu_secret_ref_ids
  install_tools    = ["curl", "git", "jq"]
  env_vars = {
    GITOPS_ENABLE_DOCKER = "1"
    GITOPS_ENABLE_NPM    = "1"
  }
}

module "remote_runner" {
  count  = trimspace(var.remote_runner_name) != "" ? 1 : 0
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = trimspace(var.remote_runner_name)
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_investigator_name} (docker/npm off PrivateSaaS network)."
  labels        = var.remote_runner_labels
}

resource "terraform_data" "gitlab_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_gitlab_integration_name) != ""
      error_message = "aios-agent-privatesaas-gitops-sre needs GitLab: inline credentials, gitlab_secret_id, or existing_gitlab_integration_name."
    }
  }
}

resource "terraform_data" "argocd_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_argocd_integration_name) != ""
      error_message = "aios-agent-privatesaas-gitops-sre needs Argo CD: inline credentials, argocd_secret_id, or existing_argocd_integration_name."
    }
  }
}

resource "terraform_data" "sonarqube_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_sonarqube_integration_name) != ""
      error_message = "aios-agent-privatesaas-gitops-sre needs SonarQube: inline credentials, sonarqube_secret_id, or existing_sonarqube_integration_name."
    }
  }
}

resource "terraform_data" "aws_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_aws_integration_name) != ""
      error_message = "aios-agent-privatesaas-gitops-sre needs AWS: provide aws_secret_id or existing_aws_integration_name."
    }
  }
}

resource "terraform_data" "slack_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_slack_integration_name) != ""
      error_message = "aios-agent-privatesaas-gitops-sre needs Slack: slack_bot_token, slack_secret_id, or existing_slack_integration_name."
    }
  }
}

resource "terraform_data" "remote_runner_name_required" {
  lifecycle {
    precondition {
      condition     = !var.create_remote_runner || trimspace(var.remote_runner_name) != ""
      error_message = "create_remote_runner requires a non-empty remote_runner_name."
    }
  }
}

# =============================================================================
# Agents
# =============================================================================

resource "sg_agent" "slack_sre_intake" {
  name        = local.agent_intake_name
  persona     = file("${path.module}/personas/slack-sre-intake.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_slack_integration_name,
    local.resolved_gitlab_integration_name,
  ])
}

resource "sg_agent" "gitops_sre_investigator" {
  name        = local.agent_investigator_name
  persona     = file("${path.module}/personas/gitops-sre-investigator.md")
  model_names = compact(var.model_names)

  remote_runners = local.remote_runner_names

  integrations = local.investigator_integrations
}

resource "sg_agent" "gitops_sre_remediator" {
  name        = local.agent_remediator_name
  persona     = file("${path.module}/personas/gitops-sre-remediator.md")
  model_names = compact(var.model_names)

  remote_runners = local.remote_runner_names

  hitl = {
    always_allowed = compact([
      local.resolved_argocd_integration_name != "" ? "${local.resolved_argocd_integration_name}_test_connection" : "",
    ])
  }

  integrations = local.remediator_integrations
}

resource "sg_agent_budget" "slack_sre_intake" {
  agent_name  = sg_agent.slack_sre_intake.name
  limit_usd   = var.agent_budgets.intake
  period_type = "daily"
}

resource "sg_agent_budget" "gitops_sre_investigator" {
  agent_name  = sg_agent.gitops_sre_investigator.name
  limit_usd   = var.agent_budgets.investigator
  period_type = "daily"
}

resource "sg_agent_budget" "gitops_sre_remediator" {
  agent_name  = sg_agent.gitops_sre_remediator.name
  limit_usd   = var.agent_budgets.remediator
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "slack_sre_intake_dangerous_ops" {
  agent_name = sg_agent.slack_sre_intake.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "gitops_sre_investigator_dangerous_ops" {
  agent_name = sg_agent.gitops_sre_investigator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "gitops_sre_remediator_dangerous_ops" {
  agent_name = sg_agent.gitops_sre_remediator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "gitops_sre_remediator_sre_remediation" {
  count      = local.attach_policy.sre_remediation ? 1 : 0
  agent_name = sg_agent.gitops_sre_remediator.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "gitops_sre_remediator_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate ? 1 : 0
  agent_name = sg_agent.gitops_sre_remediator.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

# =============================================================================
# Runbooks
# =============================================================================

resource "sg_runbook_sop" "normalize_slack" {
  name        = local.sop_normalize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-normalize-slack-request.md", local.template_vars))
}

resource "sg_runbook_sop" "correlate_gitlab" {
  name        = local.sop_gitlab_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-correlate-gitlab.md", local.template_vars))
}

resource "sg_runbook_sop" "inspect_argocd" {
  name        = local.sop_argocd_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-inspect-argocd.md", local.template_vars))
}

resource "sg_runbook_sop" "inspect_dynamodb" {
  name        = local.sop_dynamodb_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-inspect-dynamodb.md", local.template_vars))
}

resource "sg_runbook_sop" "inspect_containers" {
  name        = local.sop_containers_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-inspect-containers.md", local.template_vars))
}

resource "sg_runbook_sop" "assess_sonarqube" {
  name        = local.sop_sonarqube_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-assess-sonarqube.md", local.template_vars))
}

resource "sg_runbook_sop" "synthesize_rca" {
  name        = local.sop_synthesize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-synthesize-rca.md", local.template_vars))
}

resource "sg_runbook_sop" "recommend_notify" {
  name        = local.sop_remediate_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-recommend-and-notify.md", local.template_vars))
}

resource "sg_runbook_sop" "gitlab_branch_scan" {
  name        = local.sop_gitlab_audit_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-gitlab-branch-scan.md", local.template_vars))
}

resource "sg_runbook_sop" "sonarqube_metrics" {
  name        = local.sop_sonar_audit_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-sonarqube-metrics.md", local.template_vars))
}

resource "sg_runbook_sop" "dynamodb_capacity" {
  name        = local.sop_dynamo_audit_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-dynamodb-capacity-review.md", local.template_vars))
}

# =============================================================================
# Evidence checklist
# =============================================================================

resource "sg_evidence_checklist" "gitops_sre_rca" {
  count       = var.enable_evidence_checklist ? 1 : 0
  name        = local.evidence_name
  description = "Proof-of-work for GitOps SRE RCA before Slack remediation notify."
  approve     = true
  required_items = [
    "gitlab_pipeline_linked",
    "argocd_app_identified",
    "dynamodb_table_reviewed",
    "sonarqube_gate_checked",
    "root_cause_stated",
  ]
  scoring = {
    min_required         = 4
    confidence_threshold = 0.70
  }
  metadata = { playbook = "gitops-sre-incident-response" }
}

# =============================================================================
# Workflow — GitOps SRE incident response
# =============================================================================

resource "sg_workflow" "gitops_sre_incident_response" {
  name        = local.workflow_incident_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-gitops-sre-incident-response.md", local.template_vars))
  approve     = true

  evidence_checklist_ref = var.enable_evidence_checklist ? sg_evidence_checklist.gitops_sre_rca[0].name : null

  metadata = {
    planner_max_tool_iterations = 45
  }

  triggers = [
    { field = "source", values = ["slack"], type = "active", source = "slack" },
    { field = "incident_title_contains", values = ["aiden", "npm", "deploy", "pipeline", "argocd", "gitlab"], type = "passive" },
  ]

  required_inputs = ["slack_text"]
  optional_inputs = ["channel", "thread_ts", "environment", "gitlab_project"]

  runbook_refs = [
    sg_runbook_sop.normalize_slack.name,
    sg_runbook_sop.correlate_gitlab.name,
    sg_runbook_sop.inspect_argocd.name,
    sg_runbook_sop.inspect_dynamodb.name,
    sg_runbook_sop.inspect_containers.name,
    sg_runbook_sop.assess_sonarqube.name,
    sg_runbook_sop.synthesize_rca.name,
    sg_runbook_sop.recommend_notify.name,
  ]

  example_queries = [
    "/aiden npm install failed in prod checkout-api pipeline",
    "Argo CD app checkout-api OutOfSync after GitLab deploy — investigate DynamoDB throttles",
    "GitLab pipeline failed on main — SonarQube gate and docker pull errors in thread",
  ]

  stages = [
    { stage_id = "slack-ingest-filter", description = "Deterministic Rego filter (allowed channels, environment tags, blocked substrings).", required = true },
    { stage_id = "normalize-slack-request", description = "Parse Slack /aiden or thread into normalized_request JSON.", required = true },
    { stage_id = "correlate-gitlab", description = "GitLab pipeline, MR, and commit correlation (read-only).", required = true },
    { stage_id = "inspect-argocd", description = "Argo CD app health, sync status, events (read-only).", required = true },
    { stage_id = "inspect-dynamodb", description = "AWS DynamoDB throttles, hot partitions, table status (read-only).", required = true },
    { stage_id = "inspect-containers", description = "Docker image pull and npm diagnostics via Ubuntu when enabled.", required = true },
    { stage_id = "assess-sonarqube", description = "SonarQube quality gate and new issues on branch (read-only).", required = true },
    { stage_id = "synthesize-rca", description = "Cross-signal RCA synthesis.", required = true },
    { stage_id = "remediation-safety-gate", description = "Inline Rego blocks P1/critical auto-remediation.", required = true },
    { stage_id = "recommend-and-notify", description = "Post Slack summary with bounded remediation steps.", required = true },
  ]

  stage_bindings = [
    {
      stage_id    = "slack-ingest-filter"
      action_type = "policy_check"
      action_config = {
        inline_rego = local.slack_ingest_filter_rego
      }
    },
    {
      stage_id         = "normalize-slack-request"
      agent_ref        = sg_agent.slack_sre_intake.name
      stage_depends_on = ["slack-ingest-filter"]
      runbook_refs     = [sg_runbook_sop.normalize_slack.name]
      skill_refs       = concat(["gitops-normalize-slack"], try(var.workflow_skill_refs["gitops-sre-incident-response::normalize-slack-request"], []))
      note             = "Normalize Slack intake into stable request envelope."
    },
    {
      stage_id         = "correlate-gitlab"
      agent_ref        = sg_agent.gitops_sre_investigator.name
      stage_depends_on = ["normalize-slack-request"]
      runbook_refs     = [sg_runbook_sop.correlate_gitlab.name]
      skill_refs       = concat(["gitops-correlate-gitlab"], try(var.workflow_skill_refs["gitops-sre-incident-response::correlate-gitlab"], []))
      note             = "Correlate GitLab pipeline and MR signals."
    },
    {
      stage_id         = "inspect-argocd"
      agent_ref        = sg_agent.gitops_sre_investigator.name
      stage_depends_on = ["correlate-gitlab"]
      runbook_refs     = [sg_runbook_sop.inspect_argocd.name]
      skill_refs       = concat(["gitops-inspect-argocd"], try(var.workflow_skill_refs["gitops-sre-incident-response::inspect-argocd"], []))
      note             = "Inspect Argo CD application health and sync (read-only)."
    },
    {
      stage_id         = "inspect-dynamodb"
      agent_ref        = sg_agent.gitops_sre_investigator.name
      stage_depends_on = ["inspect-argocd"]
      runbook_refs     = [sg_runbook_sop.inspect_dynamodb.name]
      skill_refs       = concat(["gitops-inspect-dynamodb"], try(var.workflow_skill_refs["gitops-sre-incident-response::inspect-dynamodb"], []))
      note             = "Inspect DynamoDB capacity and throttles."
    },
    {
      stage_id         = "inspect-containers"
      agent_ref        = sg_agent.gitops_sre_investigator.name
      stage_depends_on = ["inspect-dynamodb"]
      runbook_refs     = [sg_runbook_sop.inspect_containers.name]
      skill_refs       = concat(["gitops-inspect-containers"], try(var.workflow_skill_refs["gitops-sre-incident-response::inspect-containers"], []))
      note             = "Docker/npm diagnostics when Ubuntu integration is enabled."
    },
    {
      stage_id         = "assess-sonarqube"
      agent_ref        = sg_agent.gitops_sre_investigator.name
      stage_depends_on = ["inspect-containers"]
      runbook_refs     = [sg_runbook_sop.assess_sonarqube.name]
      skill_refs       = concat(["gitops-assess-sonarqube"], try(var.workflow_skill_refs["gitops-sre-incident-response::assess-sonarqube"], []))
      note             = "Assess SonarQube quality gate on branch."
    },
    {
      stage_id         = "synthesize-rca"
      agent_ref        = sg_agent.gitops_sre_investigator.name
      stage_depends_on = ["assess-sonarqube"]
      runbook_refs     = [sg_runbook_sop.synthesize_rca.name]
      skill_refs       = concat(["gitops-synthesize-rca"], try(var.workflow_skill_refs["gitops-sre-incident-response::synthesize-rca"], []))
      note             = "Synthesize GitOps RCA report."
    },
    {
      stage_id         = "remediation-safety-gate"
      action_type      = "policy_check"
      stage_depends_on = ["synthesize-rca"]
      action_config = {
        inline_rego = <<-REGO
          package stage_gate

          import rego.v1

          default allow = true

          allow = false if { is_critical_severity }

          _text := lower(input.stage_input)

          is_critical_severity if { regex.match(`\bp1\b`, _text) }
          is_critical_severity if { regex.match(`\bsev[- ]?1\b`, _text) }
          is_critical_severity if { contains(_text, "severity: 1") }
          is_critical_severity if { regex.match(`\bcritical\b`, _text) }

          deny contains "P1/critical incident requires human-in-the-loop before auto-remediation" if {
              is_critical_severity
          }
        REGO
      }
    },
    {
      stage_id         = "recommend-and-notify"
      agent_ref        = sg_agent.gitops_sre_remediator.name
      stage_depends_on = ["remediation-safety-gate"]
      runbook_refs     = [sg_runbook_sop.recommend_notify.name]
      skill_refs       = concat(["gitops-recommend-notify"], try(var.workflow_skill_refs["gitops-sre-incident-response::recommend-and-notify"], []))
      note             = "Post Slack remediation summary (bounded actions)."
    },
  ]
}

# =============================================================================
# Workflow — GitOps SRE quality audit (read-only)
# =============================================================================

resource "sg_workflow" "gitops_sre_quality_audit" {
  name        = local.workflow_audit_name
  domain      = "devops"
  description = trimspace(templatefile("${path.module}/templates/workflow-gitops-sre-quality-audit.md", local.template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = 30
  }

  triggers = [
    { field = "incident_title_contains", values = ["audit", "quality", "sonarqube", "dynamodb", "gitlab"], type = "passive" },
  ]

  runbook_refs = [
    sg_runbook_sop.gitlab_branch_scan.name,
    sg_runbook_sop.sonarqube_metrics.name,
    sg_runbook_sop.dynamodb_capacity.name,
  ]

  example_queries = [
    "Run GitOps quality audit — GitLab branches, SonarQube metrics, DynamoDB capacity",
    "Read-only SonarQube and DynamoDB review for prod services",
  ]

  stages = [
    { stage_id = "gitlab-branch-scan", description = "Read-only GitLab branch and pipeline scan.", required = true },
    { stage_id = "sonarqube-metrics", description = "Read-only SonarQube project metrics.", required = true },
    { stage_id = "dynamodb-capacity-review", description = "Read-only DynamoDB capacity and throttle review.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "gitlab-branch-scan"
      agent_ref    = sg_agent.gitops_sre_investigator.name
      runbook_refs = [sg_runbook_sop.gitlab_branch_scan.name]
      skill_refs   = concat(["gitops-gitlab-branch-scan"], try(var.workflow_skill_refs["gitops-sre-quality-audit::gitlab-branch-scan"], []))
      note         = "GitLab branch scan for quality audit."
    },
    {
      stage_id         = "sonarqube-metrics"
      agent_ref        = sg_agent.gitops_sre_investigator.name
      stage_depends_on = ["gitlab-branch-scan"]
      runbook_refs     = [sg_runbook_sop.sonarqube_metrics.name]
      skill_refs       = concat(["gitops-sonarqube-metrics"], try(var.workflow_skill_refs["gitops-sre-quality-audit::sonarqube-metrics"], []))
      note             = "SonarQube metrics audit."
    },
    {
      stage_id         = "dynamodb-capacity-review"
      agent_ref        = sg_agent.gitops_sre_investigator.name
      stage_depends_on = ["sonarqube-metrics"]
      runbook_refs     = [sg_runbook_sop.dynamodb_capacity.name]
      skill_refs       = concat(["gitops-dynamodb-capacity"], try(var.workflow_skill_refs["gitops-sre-quality-audit::dynamodb-capacity-review"], []))
      note             = "DynamoDB capacity review."
    },
  ]
}

# =============================================================================
# Slack webhook ingress
# =============================================================================

resource "sg_webhook" "slack_gitops_sre" {
  count = var.enable_slack_webhook ? 1 : 0

  name          = local.webhook_name
  target_type   = "workflow"
  target_name   = sg_workflow.gitops_sre_incident_response.name
  action        = "A Slack message triggered GitOps SRE intake (/aiden, npm, deploy, or pipeline failure). Apply ingest filters, investigate GitLab/Argo CD/AWS/SonarQube, synthesize RCA, and post bounded remediation to Slack."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
