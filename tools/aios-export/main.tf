# =============================================================================
# tools/aios-export — Aiden tenant -> HCL exporter (Phase 1)
# =============================================================================
# Read-only Terraform root: uses the StackGen provider's data sources to
# capture a snapshot of a Guild tenant (agents, workflows, remote runners,
# the authenticated identity). The snapshot is exposed via the
# `tenant_snapshot` output and consumed by ../export.sh / emit-hcl.py.
#
# Phase 1 scope:
#   - Capture what the provider exposes as data sources.
#   - Emit a JSON snapshot.
#   - Emit raw `sg_agent` / `sg_workflow` / `sg_remote_runner` HCL stubs.
#
# Phase 2 (separate workstream): pattern-match agent / workflow names into
# this repo's modules so the emitted HCL is idiomatic (e.g. five SRE agents
# with matching names -> `module "sre_agents" { source = ".../aios-agent-sre" }`).

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.20, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

data "sg_me" "current" {}

data "sg_agents" "all" {}

data "sg_workflows" "all" {
  include_drafts = var.include_drafts
  latest_only    = var.latest_only
}

data "sg_remote_runners" "all" {}
