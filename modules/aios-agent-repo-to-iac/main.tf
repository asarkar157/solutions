terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.4, < 0.2.0" }
  }
}

# =============================================================================
# Repository → IaC (StackGen MCP + GitHub)
# =============================================================================
# Workflow: resolve GitHub URL → analyze repo contents → generate IaC via
# StackGen MCP tools → summarize deliverables.

resource "sg_agent" "repo_iac_architect" {
  name        = "repository-iac-architect"
  persona     = file("${path.module}/personas/repo-to-iac-architect.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  integrations = compact([
    var.github_integration_name,
    var.stackgen_mcp_integration_name != "" ? var.stackgen_mcp_integration_name : null,
  ])

  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }
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
  name        = "repository-structure-discovery"
  description = trimspace(templatefile("${path.module}/templates/repository-structure-discovery.md", {}))
}

resource "sg_runbook_sop" "stackgen_iac_synthesis" {
  name        = "stackgen-iac-synthesis"
  description = trimspace(templatefile("${path.module}/templates/stackgen-iac-synthesis.md", {}))
}

resource "sg_runbook_sop" "deliverable_handoff" {
  name        = "repo-to-iac-deliverable-handoff"
  description = trimspace(templatefile("${path.module}/templates/repo-to-iac-deliverable-handoff.md", {}))
}

resource "sg_workflow" "repository_to_iac" {
  name        = "repository-to-iac"
  domain      = "platform-engineering"
  description = trimspace(templatefile("${path.module}/templates/workflow-repository-to-iac.md", {}))
  approve     = true

  required_inputs = ["github_repo_url"]
  optional_inputs = ["default_branch", "target_cloud", "iac_scope"]

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
      note         = "Architect resolves URL and gathers manifest inventory via GitHub tools."
    },
    {
      stage_id         = "analyze-repository"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["fetch-repository-metadata"]
      runbook_refs     = [sg_runbook_sop.repository_discovery.name]
      note             = "Architect classifies stack and defines target IaC shape."
    },
    {
      stage_id         = "generate-iac-stackgen"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["analyze-repository"]
      runbook_refs     = [sg_runbook_sop.stackgen_iac_synthesis.name]
      note             = "Architect drives StackGen MCP tools to emit IaC aligned with the repo."
    },
    {
      stage_id         = "summarize-deliverables"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["generate-iac-stackgen"]
      runbook_refs     = [sg_runbook_sop.deliverable_handoff.name]
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
  name        = "repo-appstack-infer-plan"
  description = trimspace(templatefile("${path.module}/templates/repo-appstack-infer-plan.md", {}))
}

resource "sg_runbook_sop" "repo_appstack_provision_env" {
  name        = "repo-appstack-provision-env"
  description = trimspace(templatefile("${path.module}/templates/repo-appstack-provision-env.md", {}))
}

resource "sg_runbook_sop" "repo_appstack_artifact_export_github" {
  name        = "repo-appstack-artifact-export-github"
  description = trimspace(templatefile("${path.module}/templates/repo-appstack-artifact-export-github.md", {}))
}

resource "sg_workflow" "repo_scan_appstack_github_export" {
  name        = "repo-scan-appstack-github-export"
  domain      = "platform-engineering"
  description = trimspace(templatefile("${path.module}/templates/workflow-repo-scan-appstack-github-export.md", {}))
  approve     = true

  required_inputs = ["github_repo_url", "export_github_repo"]
  optional_inputs = ["default_branch", "aws_region", "stackgen_project_name", "export_branch"]

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
      note         = "Architect scans source github_repo_url via GitHub tools."
    },
    {
      stage_id         = "infer-modules-and-appstack-plan"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["scan-github-repository"]
      runbook_refs     = [sg_runbook_sop.repo_appstack_infer_plan.name]
      note             = "Architect maps repo to StackGen types, packs, templates."
    },
    {
      stage_id         = "provision-appstack-and-env"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["infer-modules-and-appstack-plan"]
      runbook_refs     = [sg_runbook_sop.repo_appstack_provision_env.name]
      note             = "Architect creates canvas IaC and env aligned with AWS/region inputs."
    },
    {
      stage_id         = "build-deployable-artifact"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["provision-appstack-and-env"]
      runbook_refs     = [sg_runbook_sop.repo_appstack_artifact_export_github.name]
      note             = "Architect runs action pipeline for deployable output."
    },
    {
      stage_id         = "export-iac-to-github"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["build-deployable-artifact"]
      runbook_refs     = [sg_runbook_sop.repo_appstack_artifact_export_github.name]
      note             = "Architect executes StackGen Export to export_github_repo."
    },
    {
      stage_id         = "summarize-handoff"
      agent_ref        = sg_agent.repo_iac_architect.name
      stage_depends_on = ["export-iac-to-github"]
      runbook_refs     = [sg_runbook_sop.deliverable_handoff.name]
      note             = "Architect closes with links and evidence."
    },
  ]
}
