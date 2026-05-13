terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

# =============================================================================
# Microservice Release & Tag Tracker (read-only, GitHub-driven)
# =============================================================================

resource "sg_agent" "release_tracker" {
  name        = "release-tracker"
  persona     = file("${path.module}/personas/release-tracker.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }

  integrations = compact([
    lookup(var.integration_names, "github", ""),
    lookup(var.integration_names, "slack", ""),
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
  name    = "latest-tags-and-releases"
  approve = true
  description = trimspace(templatefile("${path.module}/templates/latest-tags-and-releases.md", {
    tag_limit     = var.tag_limit
    release_limit = var.release_limit
  }))
}

resource "sg_runbook_sop" "container_image_tag_discovery" {
  name    = "container-image-tag-discovery"
  approve = true
  description = trimspace(templatefile("${path.module}/templates/container-image-tag-discovery.md", {
    tag_limit = var.tag_limit
  }))
}

resource "sg_runbook_sop" "deployed_version_correlation" {
  name        = "deployed-version-correlation"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/deployed-version-correlation.md", {}))
}

resource "sg_runbook_sop" "release_diff" {
  name        = "release-diff"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/release-diff.md", {}))
}

# -----------------------------------------------------------------------------
# Workflow — single conversational entrypoint
# -----------------------------------------------------------------------------

resource "sg_workflow" "release_tracking" {
  name        = "microservice-release-tracking"
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
      stage_id   = "resolve-target"
      agent_ref  = sg_agent.release_tracker.name
      note       = format("Service catalog is %s.", length(var.service_catalog) > 0 ? "configured" : "empty — operator must supply repository directly")
      skill_refs = concat(["release-tracker-resolve-target"], try(var.workflow_skill_refs["microservice-release-tracking::resolve-target"], []))
    },
    {
      stage_id         = "fetch-tags-releases"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["resolve-target"]
      runbook_refs     = [sg_runbook_sop.latest_tags_and_releases.name]
      skill_refs       = concat(["release-tracker-tags-releases"], try(var.workflow_skill_refs["microservice-release-tracking::fetch-tags-releases"], []))
    },
    {
      stage_id         = "fetch-image-tags"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["resolve-target"]
      runbook_refs     = [sg_runbook_sop.container_image_tag_discovery.name]
      note             = format("Default image namespace template: %s", var.image_namespace_template)
      skill_refs       = concat(["release-tracker-image-tags"], try(var.workflow_skill_refs["microservice-release-tracking::fetch-image-tags"], []))
    },
    {
      stage_id         = "deployed-version"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["resolve-target"]
      runbook_refs     = [sg_runbook_sop.deployed_version_correlation.name]
      skill_refs       = concat(["release-tracker-deployed-version"], try(var.workflow_skill_refs["microservice-release-tracking::deployed-version"], []))
    },
    {
      stage_id         = "diff"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["resolve-target"]
      runbook_refs     = [sg_runbook_sop.release_diff.name]
      skill_refs       = concat(["release-tracker-diff"], try(var.workflow_skill_refs["microservice-release-tracking::diff"], []))
    },
    {
      stage_id         = "compose-answer"
      agent_ref        = sg_agent.release_tracker.name
      stage_depends_on = ["fetch-tags-releases", "fetch-image-tags", "deployed-version", "diff"]
      skill_refs       = concat(["release-tracker-compose-answer"], try(var.workflow_skill_refs["microservice-release-tracking::compose-answer"], []))
    },
  ]
}
