terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.8, < 0.2.0" }
  }
}

variable "integration_names" {
  type    = map(string)
  default = {}
}

variable "model_names" {
  type = map(string)
}

resource "sg_agent" "iac_drift_detective" {
  name    = "iac-drift-detective"
  persona = file("${path.module}/personas/drift-detective.md")
  model_names = compact([
    lookup(var.model_names, "gpt4o", ""),
    lookup(var.model_names, "claude_sonnet", ""),
    lookup(var.model_names, "gemini_flash", "")
  ])
  integrations = compact([
    lookup(var.integration_names, "github", ""),
    lookup(var.integration_names, "aws", ""),
  ])
}

resource "sg_runbook_sop" "drift_scan" {
  name        = "iac-drift-scan"
  description = trimspace(templatefile("${path.module}/templates/drift-scan.md", {}))
}

resource "sg_workflow" "drift_remediation" {
  name        = "iac-drift-remediation"
  domain      = "cloudops"
  description = "Detect out-of-band cloud changes and reconcile them with Terraform code."
  approve     = true

  stages = [
    { stage_id = "run-plan", description = "Execute terraform plan and identify diffs.", required = true },
    { stage_id = "analyze-drift", description = "Determine if the drift was intentional (e.g. break-glass).", required = true },
    { stage_id = "open-pr", description = "Draft a Pull Request to backport changes to IaC.", required = true },
  ]

  stage_bindings = [
    { stage_id = "run-plan", agent_ref = sg_agent.iac_drift_detective.name, runbook_refs = [sg_runbook_sop.drift_scan.name] },
    { stage_id = "analyze-drift", agent_ref = sg_agent.iac_drift_detective.name, stage_depends_on = ["run-plan"] },
    { stage_id = "open-pr", agent_ref = sg_agent.iac_drift_detective.name, stage_depends_on = ["analyze-drift"] },
  ]
}
