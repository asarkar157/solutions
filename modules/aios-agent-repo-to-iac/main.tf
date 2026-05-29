terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  module_prefix = "repo-to-iac"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name                         = "repository-iac-architect${local.suffix}"
  workflow_repo_to_iac_name          = "repository-to-iac${local.suffix}"
  workflow_scan_appstack_export_name = "repo-scan-appstack-github-export${local.suffix}"

  sop_repository_discovery_name     = "repository-structure-discovery${local.suffix}"
  sop_iac_synthesis_name            = "stackgen-iac-synthesis${local.suffix}"
  sop_mcp_catalog_name              = "stackgen-mcp-consumer-tool-catalog-sop${local.suffix}"
  sop_deliverable_handoff_name      = "repo-to-iac-deliverable-handoff${local.suffix}"
  sop_appstack_infer_plan_name      = "repo-appstack-infer-plan${local.suffix}"
  sop_appstack_provision_env_name   = "repo-appstack-provision-env${local.suffix}"
  sop_appstack_artifact_export_name = "repo-appstack-artifact-export-github${local.suffix}"

  evidence_repo_to_iac_name   = "repository-to-iac-evidence${local.suffix}"
  evidence_scan_appstack_name = "repo-scan-appstack-github-export-evidence${local.suffix}"

  github_integration_name = "${local.module_prefix}-github${local.suffix}"

  # `provision_github` must be plan-time known (drives `count`). Consumers
  # often pass a computed `github_secret_id` (e.g. `module.github_pat[0].secret_id`)
  # so we don't inspect it here. The inner aios-integration-github module
  # surfaces a clear error when both inputs are missing.
  provision_github = trimspace(var.existing_github_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
}

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aios-agent-repo-to-iac needs a GitHub Guild integration: provide `github_secret_id` (module provisions one) or `existing_github_integration_name`."
    }
  }
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by the ${local.agent_name} agent (manifest discovery, repo metadata, export PR creation)."
}

# =============================================================================
# Repository → IaC (StackGen MCP + GitHub)
# =============================================================================
# Workflow: resolve GitHub URL → analyze repo contents → generate IaC via
# StackGen MCP tools → summarize deliverables.

resource "sg_agent" "repo_iac_architect" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/repo-to-iac-architect.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_github_integration_name,
    var.stackgen_mcp_integration_name != "" ? var.stackgen_mcp_integration_name : null,
  ])

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }

  # Consumer MCP tools (stackgen-mcp_*, etc.) bypass HITL via auto_approve_tools (not hitl.always_allowed wildcards).
  auto_approve_tools = trimspace(var.stackgen_mcp_integration_name) != "" ? [
    { tool = "${trimspace(var.stackgen_mcp_integration_name)}_*" },
  ] : null
}

resource "sg_agent_budget" "repo_iac_architect" {
  agent_name  = sg_agent.repo_iac_architect.name
  limit_usd   = var.agent_budget_usd_daily
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "repo_iac_architect_dangerous_ops" {
  agent_name = sg_agent.repo_iac_architect.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_runbook_sop" "repository_discovery" {
  name        = local.sop_repository_discovery_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/repository-structure-discovery.md", {}))
}

resource "sg_runbook_sop" "stackgen_iac_synthesis" {
  name        = local.sop_iac_synthesis_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/stackgen-iac-synthesis.md", {}))
}

resource "sg_runbook_sop" "stackgen_mcp_consumer_tool_catalog" {
  name        = local.sop_mcp_catalog_name
  approve     = true
  description = trimspace(file("${path.module}/templates/stackgen-mcp-consumer-tool-catalog.md"))
}

resource "sg_runbook_sop" "deliverable_handoff" {
  name        = local.sop_deliverable_handoff_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/repo-to-iac-deliverable-handoff.md", {}))
}

resource "sg_evidence_checklist" "repository_to_iac_evidence" {
  name        = local.evidence_repo_to_iac_name
  description = "Proof-of-work for repo→IaC: GitHub facts, stack classification, MCP actions or gap, and deliverable summary."
  approve     = true
  required_items = [
    "github_manifest_inventory_summary",
    "stack_classification_recorded",
    "iac_synthesis_or_preview_evidence",
  ]
  optional_items = ["mcp_tool_invocation_list"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.7
  }
  metadata = { playbook = "repository-to-iac" }
}

resource "sg_evidence_checklist" "repo_scan_appstack_github_export_evidence" {
  name        = local.evidence_scan_appstack_name
  description = "Proof-of-work for scan→AppStack→export: scan summary, appStack IDs, artifact/plan evidence, export PR link."
  approve     = true
  required_items = [
    "source_repo_scan_summary",
    "appstack_identifiers_and_env_profile",
    "plan_or_action_run_evidence",
  ]
  optional_items = ["export_pr_or_branch_url"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.7
  }
  metadata = { playbook = "repo-scan-appstack-github-export" }
}

resource "sg_workflow" "repository_to_iac" {
  name        = local.workflow_repo_to_iac_name
  domain      = "platform-engineering"
  description = trimspace(templatefile("${path.module}/templates/workflow-repository-to-iac.md", {}))
  approve     = true

  required_inputs        = ["github_repo_url"]
  optional_inputs        = ["default_branch", "target_cloud", "iac_scope"]
  evidence_checklist_ref = sg_evidence_checklist.repository_to_iac_evidence.name

  example_queries = [
    "Generate StackGen IaC for https://github.com/org/sample-service",
    "Turn github.com/acme/api into an appStack with Terraform aligned to the Dockerfile",
    "Import brownfield repo org/legacy-app and propose IaC using StackGen tools",
    "Analyze repo URL https://github.com/org/monorepo and scaffold infra for the worker package only",
  ]

  triggers = [
    {
      field  = "intent"
      values = ["repository-to-iac", "repo-to-iac", "generate-iac-from-repo"]
      type   = "passive"
    },
  ]

  runbook_refs = compact([
    sg_runbook_sop.repository_discovery.name,
    sg_runbook_sop.stackgen_iac_synthesis.name,
    sg_runbook_sop.stackgen_mcp_consumer_tool_catalog.name,
    sg_runbook_sop.deliverable_handoff.name,
  ])

  stages = [
    {
      stage_id    = "fetch-repository-metadata"
      description = "Resolve GitHub URL, branch, and list critical manifests (Dockerfile, k8s, workflows, Terraform)."
      note        = "Use GitHub integration tools only; collect facts for downstream IaC."
      required    = true
    },
    {
      stage_id    = "analyze-repository"
      description = "Classify stack: languages, containers, orchestration hints, existing IaC, CI/CD."
      note        = "Produce a concise deployment model: build, runtime, ports, dependencies."
      required    = true
    },
    {
      stage_id    = "generate-iac-stackgen"
      description = "Create or update IaC using StackGen MCP tools from analyzed repo context."
      note        = "Use StackGen MCP tools discovered from the attached integration."
      required    = true
    },
    {
      stage_id    = "summarize-deliverables"
      description = "Summarize StackGen resources, previews, and recommended next steps."
      note        = "Include explicit list of MCP actions taken or preview-only gap if MCP unavailable."
      required    = true
    },
  ]

  stage_bindings = [
    {
      stage_id     = "fetch-repository-metadata"
      agent_ref    = sg_agent.repo_iac_architect.name
      runbook_refs = [sg_runbook_sop.repository_discovery.name]
      skill_refs   = concat(["platform-repo-github-discovery"], try(var.workflow_skill_refs["${local.workflow_repo_to_iac_name}::fetch-repository-metadata"], []))
      note         = "Architect resolves URL and gathers manifest inventory via GitHub tools."
    },
    {
      stage_id         = "analyze-repository"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["fetch-repository-metadata"]
      runbook_refs     = [sg_runbook_sop.repository_discovery.name]
      skill_refs       = concat(["platform-repo-stack-classification"], try(var.workflow_skill_refs["${local.workflow_repo_to_iac_name}::analyze-repository"], []))
      note             = "Architect classifies stack and defines target IaC shape."
    },
    {
      stage_id         = "generate-iac-stackgen"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["analyze-repository"]
      runbook_refs = [
        sg_runbook_sop.stackgen_iac_synthesis.name,
        sg_runbook_sop.stackgen_mcp_consumer_tool_catalog.name,
      ]
      skill_refs = concat(
        ["platform-stackgen-mcp-iac-synthesis", "stackgen-mcp-consumer-tool-catalog-sop"],
        try(var.workflow_skill_refs["${local.workflow_repo_to_iac_name}::generate-iac-stackgen"], [])
      )
      note = "Architect drives StackGen MCP tools per stackgen-mcp-consumer-tool-catalog-sop (exact names from integration)."
    },
    {
      stage_id         = "summarize-deliverables"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["generate-iac-stackgen"]
      runbook_refs     = [sg_runbook_sop.deliverable_handoff.name]
      skill_refs       = concat(["platform-iac-deliverable-handoff"], try(var.workflow_skill_refs["${local.workflow_repo_to_iac_name}::summarize-deliverables"], []))
      note             = "Architect closes with structured summary and follow-ups."
    },
  ]
}

# =============================================================================
# Repo scan → AppStack → deployable artifact → Export to GitHub
# =============================================================================
# End-developer workflow: scan source repo, infer StackGen resource modules,
# materialize an appStack (connections + env aligned with AWS), produce a
# deployable artifact, then use StackGen's Export flow to push IaC to a target GitHub repo.

resource "sg_runbook_sop" "repo_appstack_infer_plan" {
  name        = local.sop_appstack_infer_plan_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/repo-appstack-infer-plan.md", {}))
}

resource "sg_runbook_sop" "repo_appstack_provision_env" {
  name        = local.sop_appstack_provision_env_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/repo-appstack-provision-env.md", {}))
}

resource "sg_runbook_sop" "repo_appstack_artifact_export_github" {
  name        = local.sop_appstack_artifact_export_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/repo-appstack-artifact-export-github.md", {}))
}

resource "sg_workflow" "repo_scan_appstack_github_export" {
  name        = local.workflow_scan_appstack_export_name
  domain      = "platform-engineering"
  description = trimspace(templatefile("${path.module}/templates/workflow-repo-scan-appstack-github-export.md", {}))
  approve     = true

  required_inputs        = ["github_repo_url", "export_github_repo"]
  optional_inputs        = ["default_branch", "aws_region", "stackgen_project_name", "export_branch"]
  evidence_checklist_ref = sg_evidence_checklist.repo_scan_appstack_github_export_evidence.name

  example_queries = [
    "Scan https://github.com/org/api-service and export StackGen IaC to github.com/org/api-infra — region us-east-1",
    "From github.com/acme/worker repo build an appStack with the right resources and export Terraform to export_github_repo org/tf-live",
    "Brownfield: analyze org/monolith, materialize appStack for the worker slice, wire env for AWS production, export to org/monolith-stackgen-export",
  ]

  triggers = [
    {
      field  = "intent"
      values = ["repo-scan-appstack-export", "repo-to-github-export", "appstack-export-github"]
      type   = "passive"
    },
  ]

  runbook_refs = compact([
    sg_runbook_sop.repo_appstack_infer_plan.name,
    sg_runbook_sop.repo_appstack_provision_env.name,
    sg_runbook_sop.repo_appstack_artifact_export_github.name,
    sg_runbook_sop.deliverable_handoff.name,
    sg_runbook_sop.stackgen_mcp_consumer_tool_catalog.name,
  ])

  stages = [
    {
      stage_id    = "scan-github-repository"
      description = "Resolve source repo URL, branch, and inventory manifests (containers, k8s, IaC, CI)."
      note        = "GitHub integration tools only; capture signals needed to choose resource types and templates."
      required    = true
    },
    {
      stage_id    = "infer-modules-and-appstack-plan"
      description = "Derive required StackGen resource types, packs, optional template appStack, and connection graph from the scan."
      note        = "Use Consumer MCP discovery tools; produce a concrete plan (identifiers, resource_type strings, UUIDs)."
      required    = true
    },
    {
      stage_id    = "provision-appstack-and-env"
      description = "Create the appStack, add resources/packs, connect resources, and configure env profiles with AWS region/account context."
      note        = "Prefer stackgen-mcp_create_appstack, add_resource*, connect_resources, env profile APIs; honor aws_region optional input."
      required    = true
    },
    {
      stage_id    = "build-deployable-artifact"
      description = "Run platform build/plan pipeline to produce a deployable artifact and capture logs."
      note        = "Typically stackgen-mcp_create_appstack_action_run + get_action_run_logs; snapshot optional."
      required    = true
    },
    {
      stage_id    = "export-iac-to-github"
      description = "Export generated IaC from StackGen to the target GitHub repository (Export feature)."
      note        = "Use StackGen Export toward export_github_repo; open PR or branch per policy; no secrets in plaintext export."
      required    = true
    },
    {
      stage_id    = "summarize-handoff"
      description = "Summarize appStack IDs, artifact location, export PR/repo link, and follow-ups."
      note        = "Structured handoff for developers and platform reviewers."
      required    = true
    },
  ]

  stage_bindings = [
    {
      stage_id     = "scan-github-repository"
      agent_ref    = sg_agent.repo_iac_architect.name
      runbook_refs = [sg_runbook_sop.repository_discovery.name]
      skill_refs   = concat(["platform-repo-github-scan"], try(var.workflow_skill_refs["${local.workflow_scan_appstack_export_name}::scan-github-repository"], []))
      note         = "Architect scans source github_repo_url via GitHub tools."
    },
    {
      stage_id         = "infer-modules-and-appstack-plan"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["scan-github-repository"]
      runbook_refs = [
        sg_runbook_sop.repo_appstack_infer_plan.name,
        sg_runbook_sop.stackgen_mcp_consumer_tool_catalog.name,
      ]
      skill_refs = concat(
        ["platform-appstack-infer-plan", "stackgen-mcp-consumer-tool-catalog-sop"],
        try(var.workflow_skill_refs["${local.workflow_scan_appstack_export_name}::infer-modules-and-appstack-plan"], [])
      )
      note = "Architect maps repo to StackGen types, packs, templates (full MCP catalog skill)."
    },
    {
      stage_id         = "provision-appstack-and-env"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["infer-modules-and-appstack-plan"]
      runbook_refs = [
        sg_runbook_sop.repo_appstack_provision_env.name,
        sg_runbook_sop.stackgen_mcp_consumer_tool_catalog.name,
      ]
      skill_refs = concat(
        ["platform-appstack-provision-env", "stackgen-mcp-consumer-tool-catalog-sop"],
        try(var.workflow_skill_refs["${local.workflow_scan_appstack_export_name}::provision-appstack-and-env"], [])
      )
      note = "Architect creates canvas IaC and env aligned with AWS/region inputs."
    },
    {
      stage_id         = "build-deployable-artifact"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["provision-appstack-and-env"]
      runbook_refs = [
        sg_runbook_sop.repo_appstack_artifact_export_github.name,
        sg_runbook_sop.stackgen_mcp_consumer_tool_catalog.name,
      ]
      skill_refs = concat(
        ["platform-appstack-build-artifact", "stackgen-mcp-consumer-tool-catalog-sop"],
        try(var.workflow_skill_refs["${local.workflow_scan_appstack_export_name}::build-deployable-artifact"], [])
      )
      note = "Architect runs action pipeline for deployable output."
    },
    {
      stage_id         = "export-iac-to-github"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["build-deployable-artifact"]
      runbook_refs = [
        sg_runbook_sop.repo_appstack_artifact_export_github.name,
        sg_runbook_sop.stackgen_mcp_consumer_tool_catalog.name,
      ]
      skill_refs = concat(
        ["platform-stackgen-export-github", "stackgen-mcp-consumer-tool-catalog-sop"],
        try(var.workflow_skill_refs["${local.workflow_scan_appstack_export_name}::export-iac-to-github"], [])
      )
      note = "Architect executes StackGen Export (product) or GitHub/Ubuntu automation toward export_github_repo — do not assume git-push MCP tools on the default user MCP."
    },
    {
      stage_id         = "summarize-handoff"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["export-iac-to-github"]
      runbook_refs     = [sg_runbook_sop.deliverable_handoff.name]
      skill_refs       = concat(["platform-iac-export-handoff"], try(var.workflow_skill_refs["${local.workflow_scan_appstack_export_name}::summarize-handoff"], []))
      note             = "Architect closes with links and evidence."
    },
  ]
}
