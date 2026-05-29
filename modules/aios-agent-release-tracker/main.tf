terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.20, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "release-tracker"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name    = "${local.module_prefix}${local.suffix}"
  workflow_name = "microservice-release-tracking${local.suffix}"

  sop_latest_tags_name      = "latest-tags-and-releases${local.suffix}"
  sop_container_image_name  = "container-image-tag-discovery${local.suffix}"
  sop_deployed_version_name = "deployed-version-correlation${local.suffix}"
  sop_release_diff_name     = "release-diff${local.suffix}"

  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  slack_integration_name  = "${local.module_prefix}-slack${local.suffix}"

  # `provision_github` must be plan-time known (drives `count`). Consumers
  # often forward a computed `github_secret_id` (e.g. `module.github_pat[0].secret_id`)
  # so we don't inspect it here. The inner module surfaces a clear error
  # when both `github_secret_id` and `existing_github_integration_name` are
  # missing. Slack is optional — keeping the secret_id clause preserves the
  # "skip slack entirely when both inputs are blank" semantics.
  provision_github = trimspace(var.existing_github_integration_name) == ""
  provision_slack  = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )

  stackgen_catalog_enabled = var.enable_stackgen_deployment_catalog
  stackgen_catalog_app_names = local.stackgen_catalog_enabled ? [
    for a in data.sg_apps.configured[0].apps : a.app_name
  ] : []
}

data "sg_apps" "configured" {
  count = var.enable_stackgen_deployment_catalog ? 1 : 0

  installation = "configured"
}

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aios-agent-release-tracker needs a GitHub Guild integration: provide `github_secret_id` (module provisions one) or `existing_github_integration_name`."
    }
  }
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by the ${local.agent_name} agent (read-only tags/releases/GHCR queries)."
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
  description        = "Slack integration owned by the ${local.agent_name} agent (periodic digests + replies)."
}

# =============================================================================
# Microservice Release & Tag Tracker (read-only, GitHub-driven)
# =============================================================================

resource "sg_agent" "release_tracker" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/release-tracker.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }

  integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_slack_integration_name,
  ])
}

resource "sg_agent_budget" "release_tracker" {
  agent_name  = sg_agent.release_tracker.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.release_tracker.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# -----------------------------------------------------------------------------
# Runbooks
# -----------------------------------------------------------------------------

resource "sg_runbook_sop" "latest_tags_and_releases" {
  name    = local.sop_latest_tags_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/latest-tags-and-releases.md", {
    tag_limit     = var.tag_limit
    release_limit = var.release_limit
  }))
}

resource "sg_runbook_sop" "container_image_tag_discovery" {
  name    = local.sop_container_image_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/container-image-tag-discovery.md", {
    tag_limit = var.tag_limit
  }))
}

resource "sg_runbook_sop" "deployed_version_correlation" {
  name    = local.sop_deployed_version_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/deployed-version-correlation.md", {
    stackgen_catalog_enabled   = local.stackgen_catalog_enabled
    stackgen_catalog_app_names = join(", ", local.stackgen_catalog_app_names)
  }))
}

resource "sg_runbook_sop" "release_diff" {
  name        = local.sop_release_diff_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/release-diff.md", {}))
}

# -----------------------------------------------------------------------------
# Workflow — single conversational entrypoint
# -----------------------------------------------------------------------------

resource "sg_workflow" "release_tracking" {
  name        = local.workflow_name
  domain      = "delivery-intelligence"
  description = trimspace(templatefile("${path.module}/templates/workflow-release-tracking.md", {}))
  approve     = true

  required_inputs = ["question"]
  optional_inputs = [
    "repository",
    "repositories",
    "service_name",
    "environment",
    "image",
    "from_ref",
    "to_ref",
    "include_prereleases",
    "limit",
    "service_catalog",
  ]

  example_queries = [
    "What's the latest tag of payments-service?",
    "Show me the last 5 releases of appcd-dev/solutions",
    "Which version of order-service is currently deployed in production?",
    "What changed between v2.4.0 and v2.5.0 of checkout-api?",
    "List the latest GHCR image tags for the search service",
    "Is the manifest in the platform repo pinned to the latest release of payments?",
  ]

  stages = [
    { stage_id = "resolve-target", description = "Map service_name → repository (via service_catalog) or normalize the supplied repository / image.", required = true },
    { stage_id = "fetch-tags-releases", description = "Fetch latest tags and GitHub Releases (stable + optional pre-releases).", required = false },
    { stage_id = "fetch-image-tags", description = "Fetch latest container image versions from the configured registry.", required = false },
    { stage_id = "deployed-version", description = "Resolve the version currently deployed in the requested environment (deployments + optional manifest).", required = false },
    { stage_id = "diff", description = "Diff two refs / tags and produce a PR-grouped changelog.", required = false },
    { stage_id = "compose-answer", description = "Render the linked Markdown answer; include source URLs.", required = true },
  ]

  stage_bindings = [
    {
      stage_id  = "resolve-target"
      agent_ref = sg_agent.release_tracker.name
      note = format(
        "Service catalog is %s.%s",
        length(var.service_catalog) > 0 ? "configured" : "empty — operator must supply repository directly",
        local.stackgen_catalog_enabled ? format(" StackGen deployment-catalog apps (configured): %s.", join(", ", local.stackgen_catalog_app_names)) : "",
      )
      skill_refs = concat(["release-tracker-resolve-target"], try(var.workflow_skill_refs["${local.workflow_name}::resolve-target"], []))
    },
    {
      stage_id         = "fetch-tags-releases"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["resolve-target"]
      runbook_refs     = [sg_runbook_sop.latest_tags_and_releases.name]
      skill_refs       = concat(["release-tracker-tags-releases"], try(var.workflow_skill_refs["${local.workflow_name}::fetch-tags-releases"], []))
    },
    {
      stage_id         = "fetch-image-tags"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["resolve-target"]
      runbook_refs     = [sg_runbook_sop.container_image_tag_discovery.name]
      note             = format("Default image namespace template: %s", var.image_namespace_template)
      skill_refs       = concat(["release-tracker-image-tags"], try(var.workflow_skill_refs["${local.workflow_name}::fetch-image-tags"], []))
    },
    {
      stage_id         = "deployed-version"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["resolve-target"]
      runbook_refs     = [sg_runbook_sop.deployed_version_correlation.name]
      skill_refs       = concat(["release-tracker-deployed-version"], try(var.workflow_skill_refs["${local.workflow_name}::deployed-version"], []))
    },
    {
      stage_id         = "diff"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["resolve-target"]
      runbook_refs     = [sg_runbook_sop.release_diff.name]
      skill_refs       = concat(["release-tracker-diff"], try(var.workflow_skill_refs["${local.workflow_name}::diff"], []))
    },
    {
      stage_id         = "compose-answer"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["fetch-tags-releases", "fetch-image-tags", "deployed-version", "diff"]
      skill_refs       = concat(["release-tracker-compose-answer"], try(var.workflow_skill_refs["${local.workflow_name}::compose-answer"], []))
    },
  ]
}
