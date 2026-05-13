terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

variable "integration_names" {
  type    = map(string)
  default = {}
}

variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "iac-drift-remediation::<stage_id>" (run-plan, analyze-drift, open-pr). Each value is appended after module defaults.
  EOT
  type        = map(list(string))
  default     = {}
}

variable "remote_runner_name" {
  description = <<-EOT
    Optional Guild remote runner name. When `remote_runner_attach_to_agent` is true, looked up with
    `data.sg_remote_runner` and set on `sg_agent.remote_runners`.
  EOT
  type        = string
  default     = ""
}

variable "remote_runner_attach_to_agent" {
  description = "When true, attach `remote_runner_name` to the drift agent. Requires non-empty `remote_runner_name`."
  type        = bool
  default     = false

  validation {
    condition     = !var.remote_runner_attach_to_agent || trimspace(var.remote_runner_name) != ""
    error_message = "remote_runner_attach_to_agent requires a non-empty remote_runner_name."
  }
}

data "sg_remote_runner" "iac_drift_detective" {
  count = var.remote_runner_attach_to_agent ? 1 : 0
  name  = trimspace(var.remote_runner_name)
}

resource "sg_agent" "iac_drift_detective" {
  name           = "iac-drift-detective"
  persona        = file("${path.module}/personas/drift-detective.md")
  model_names    = compact(var.model_names)
  remote_runners = length(data.sg_remote_runner.iac_drift_detective) > 0 ? toset([data.sg_remote_runner.iac_drift_detective[0].name]) : null
  integrations = compact([
    lookup(var.integration_names, "github", ""),
    lookup(var.integration_names, "aws", ""),
  ])
}

resource "sg_runbook_sop" "drift_scan" {
  name        = "iac-drift-scan"
  approve     = true
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
    {
      stage_id     = "run-plan"
      agent_ref    = sg_agent.iac_drift_detective.name
      runbook_refs = [sg_runbook_sop.drift_scan.name]
      skill_refs   = concat(["iac-drift-plan-and-diff"], try(var.workflow_skill_refs["iac-drift-remediation::run-plan"], []))
    },
    {
      stage_id         = "analyze-drift"
      agent_ref        = sg_agent.iac_drift_detective.name
      stage_depends_on = ["run-plan"]
      skill_refs       = concat(["iac-drift-intent-classification"], try(var.workflow_skill_refs["iac-drift-remediation::analyze-drift"], []))
    },
    {
      stage_id         = "open-pr"
      agent_ref        = sg_agent.iac_drift_detective.name
      stage_depends_on = ["analyze-drift"]
      skill_refs       = concat(["iac-drift-backport-pr"], try(var.workflow_skill_refs["iac-drift-remediation::open-pr"], []))
    },
  ]
}
