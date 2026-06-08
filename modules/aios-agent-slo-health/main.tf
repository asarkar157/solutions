terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

locals {
  module_prefix = "slo-health"
  suffix        = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name              = "${local.module_prefix}${local.suffix}"
  workflow_review_name    = "slo-health-review${local.suffix}"
  workflow_bootstrap_name = "slo-definition-bootstrap${local.suffix}"
  workflow_drift_name     = "slo-drift-reconcile${local.suffix}"
  webhook_bootstrap_name  = "slo-bootstrap-ingress${local.suffix}"
  webhook_drift_name      = "slo-drift-ingress${local.suffix}"

  github_integration_name  = "${local.module_prefix}-github${local.suffix}"
  grafana_integration_name = "${local.module_prefix}-grafana${local.suffix}"
  slack_integration_name   = "${local.module_prefix}-slack${local.suffix}"
  ubuntu_integration_name  = "${local.module_prefix}-ubuntu${local.suffix}"

  sop_fetch_name          = "fetch-openslo-specs${local.suffix}"
  sop_scan_config_name    = "scan-grafana-config${local.suffix}"
  sop_detect_drift_name   = "detect-config-drift${local.suffix}"
  sop_query_metrics_name  = "query-slo-metrics${local.suffix}"
  sop_assess_budget_name  = "assess-error-budget${local.suffix}"
  sop_compose_digest_name = "compose-slo-digest${local.suffix}"

  sop_fetch_catalog_name     = "fetch-existing-catalog${local.suffix}"
  sop_scan_signals_name      = "scan-grafana-signals${local.suffix}"
  sop_propose_name           = "propose-slo-candidates${local.suffix}"
  sop_validate_promql_name   = "validate-promql${local.suffix}"
  sop_draft_yaml_name        = "draft-openslo-yaml${local.suffix}"
  sop_preview_proposals_name = "preview-proposals${local.suffix}"
  sop_open_slo_pr_name       = "open-slo-pr${local.suffix}"
  sop_notify_bootstrap_name  = "notify-pr-opened${local.suffix}"

  sop_fetch_drift_name     = "fetch-catalog-and-grafana${local.suffix}"
  sop_classify_drift_name  = "classify-drift-items${local.suffix}"
  sop_draft_reconcile_name = "draft-reconcile-yaml${local.suffix}"
  sop_preview_drift_name   = "preview-drift-fixes${local.suffix}"
  sop_open_drift_pr_name   = "open-drift-pr${local.suffix}"
  sop_notify_drift_name    = "notify-drift-pr${local.suffix}"

  provision_github  = trimspace(var.existing_github_integration_name) == ""
  provision_grafana = trimspace(var.grafana_secret_id) != "" && trimspace(var.existing_grafana_integration_name) == ""
  provision_slack   = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""

  pr_workflow_enabled = var.enable_slo_bootstrap_workflow || var.enable_slo_drift_reconcile_workflow

  create_ubuntu_integration = (
    local.pr_workflow_enabled
    && (var.enable_ubuntu_cli || var.create_remote_runner)
    && trimspace(var.existing_ubuntu_integration_name) == ""
  )

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_grafana_integration_name = trimspace(var.existing_grafana_integration_name) != "" ? var.existing_grafana_integration_name : (
    local.provision_grafana ? module.grafana_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_ubuntu_integration_name = coalesce(
    trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : null,
    try(module.ubuntu_integration[0].integration_name, null),
    "",
  )

  remote_runner_names = (
    var.create_remote_runner
    && var.remote_runner_attach_to_agent
    && length(module.remote_runner) > 0
  ) ? toset([module.remote_runner[0].runner_name]) : null

  slack_notify_enabled   = trimspace(local.resolved_slack_integration_name) != ""
  webhook_notify_enabled = trimspace(var.slo_report_webhook_url) != ""
  shell_runner_required  = local.pr_workflow_enabled

  openslo_authoritative_config_note = <<-EOT
AUTHORITATIVE OpenSLO Git config (Terraform — overrides any Repo: line in chat or workflow prompt):
- repository_full_name: ${var.openslo_repository_full_name}
- branch: ${var.openslo_branch}
- path_prefix: ${var.openslo_path_prefix}
If the user prompt names a different GitHub repo or path, ignore it and use the values above only.
EOT

  bootstrap_stage_inline_note = "${local.openslo_authoritative_config_note}\nExecute this stage inline on slo-health. Do NOT call create_agent or spawn sub-agents."

  runbook_template_vars = {
    repository_full_name         = var.openslo_repository_full_name
    path_prefix                  = var.openslo_path_prefix
    branch                       = var.openslo_branch
    base_branch                  = var.openslo_pr_base_branch
    dashboard_tags_json          = jsonencode(var.discovery_dashboard_tags)
    dashboard_uids_json          = jsonencode(var.discovery_dashboard_uids)
    service_label_keys_json      = jsonencode(var.discovery_service_label_keys)
    drift_link_labels_json       = jsonencode(var.drift_link_by_labels)
    burn_rate_windows_json       = jsonencode(var.burn_rate_windows)
    at_risk_threshold_pct        = var.slo_posture_at_risk_threshold_pct
    slack_channel_hint           = var.slack_channel_hint
    max_proposals                = var.max_slo_proposals_per_run
    default_availability_target  = var.default_availability_target
    default_latency_threshold_ms = var.default_latency_threshold_ms
    promql_equivalence_mode      = var.drift_promql_equivalence_threshold
  }

  # query-slo-metrics only needs Git catalog — runs parallel with detect-config-drift when drift is enabled.
  review_query_depends_on   = ["fetch-openslo-specs"]
  review_compose_depends_on = var.enable_slo_drift_in_review ? ["assess-error-budget", "detect-config-drift"] : ["assess-error-budget"]

  parallel_batch_suffixes = slice(["a", "b", "c", "d"], 0, min(var.max_parallel_batches, 4))
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration for ${local.agent_name} (OpenSLO catalog read + PR)."
}

module "grafana_integration" {
  count  = local.provision_grafana ? 1 : 0
  source = "../aios-integration-grafana"

  integration_name   = local.grafana_integration_name
  existing_secret_id = var.grafana_secret_id
  description        = "Grafana integration for ${local.agent_name} (dashboards, alerts, PromQL)."
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
  description        = "Slack integration for ${local.agent_name} (SLO digests and PR notifications)."
}

module "remote_runner" {
  count  = trimspace(var.remote_runner_name) != "" ? 1 : 0
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = trimspace(var.remote_runner_name)
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_name} (OpenSLO PR)."
  labels        = var.remote_runner_labels
}

module "ubuntu_integration" {
  count  = local.create_ubuntu_integration ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = compact([var.github_secret_id])
  install_tools    = ["curl", "git", "gh", "jq"]
  env_vars = {
    SLO_HEALTH_SCRIPT_PACK_VERSION     = local.script_pack_version
    SLO_HEALTH_SCRIPT_PACK_TARBALL_B64 = local.script_pack_tarball_b64
    SLO_HEALTH_STAGE_RUNNER_SHA256     = local.script_pack_stage_runner_sha256
    SLO_HEALTH_DEFAULT_REPO            = var.openslo_repository_full_name
    SLO_HEALTH_DEFAULT_BRANCH          = var.openslo_pr_base_branch
    SLO_HEALTH_PATH_PREFIX             = var.openslo_path_prefix
  }
}

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aios-agent-slo-health needs GitHub: provide github_secret_id or existing_github_integration_name."
    }
  }
}

resource "terraform_data" "grafana_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_grafana_integration_name) != ""
      error_message = "aios-agent-slo-health needs Grafana: provide grafana_secret_id or existing_grafana_integration_name."
    }
  }
}

resource "terraform_data" "github_integration_provision_inputs" {
  count = local.provision_github ? 1 : 0

  lifecycle {
    precondition {
      condition     = trimspace(var.github_secret_id) != ""
      error_message = "When existing_github_integration_name is empty, github_secret_id is required."
    }
  }
}

resource "terraform_data" "grafana_integration_provision_inputs" {
  count = local.provision_grafana ? 1 : 0

  lifecycle {
    precondition {
      condition     = trimspace(var.grafana_secret_id) != ""
      error_message = "When existing_grafana_integration_name is empty, grafana_secret_id is required."
    }
  }
}

resource "terraform_data" "shell_runner_integration_required" {
  count = local.shell_runner_required ? 1 : 0

  lifecycle {
    precondition {
      condition = (
        (var.create_remote_runner && var.remote_runner_attach_to_agent && trimspace(var.remote_runner_name) != "")
        || trimspace(local.resolved_ubuntu_integration_name) != ""
      )
      error_message = "Bootstrap/drift PR workflows require Ubuntu CLI (enable_ubuntu_cli) or remote runner (create_remote_runner + remote_runner_name)."
    }
  }
}

resource "terraform_data" "remote_runner_name_required" {
  count = var.create_remote_runner ? 1 : 0

  lifecycle {
    precondition {
      condition     = trimspace(var.remote_runner_name) != ""
      error_message = "remote_runner_name is required when create_remote_runner is true."
    }
  }
}

resource "sg_agent" "slo_health" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/slo-health-analyst.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_grafana_integration_name,
    local.resolved_slack_integration_name,
    local.resolved_ubuntu_integration_name,
  ])
  remote_runners = local.remote_runner_names

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }
}

resource "sg_agent_budget" "slo_health" {
  agent_name  = sg_agent.slo_health.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.slo_health.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}
