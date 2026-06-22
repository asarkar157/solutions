terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

# =============================================================================
# Self-contained integration wiring.
# =============================================================================

variable "github_secret_id" {
  description = "Optional `sg_secret` ID for the GitHub PAT. When set, the module provisions an internal GitHub Guild integration so the drift detective can open a backport PR."
  type        = string
  default     = ""
}

variable "aws_secret_id" {
  description = "Optional `sg_secret` ID for AWS credentials. When set, the module provisions an internal AWS Guild integration so the detective can read live state."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration."
  type        = string
  default     = ""
}

variable "existing_aws_integration_name" {
  description = "Optional Guild integration name to share an existing AWS integration."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / workflow / runbook / integration resource names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
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
    Optional Guild remote runner name. Set `create_remote_runner = true` to register `sg_remote_runner` and
    expose CLI/Helm install outputs for on-prem `terraform plan` (provider >= 0.1.25).
  EOT
  type        = string
  default     = ""
}

variable "create_remote_runner" {
  description = "When true, creates sg_remote_runner via aios-remote-runner. Requires non-empty remote_runner_name."
  type        = bool
  default     = false

  validation {
    condition     = !var.create_remote_runner || trimspace(var.remote_runner_name) != ""
    error_message = "create_remote_runner requires a non-empty remote_runner_name."
  }
}

variable "remote_runner_description" {
  description = "Runner description when create_remote_runner is true."
  type        = string
  default     = ""
}

variable "remote_runner_labels" {
  description = "Optional runner labels when create_remote_runner is true."
  type        = map(string)
  default     = {}
}

variable "remote_runner_attach_to_agent" {
  description = "When true, attach remote_runner_name to the drift agent. Requires non-empty remote_runner_name."
  type        = bool
  default     = false

  validation {
    condition     = !var.remote_runner_attach_to_agent || trimspace(var.remote_runner_name) != ""
    error_message = "remote_runner_attach_to_agent requires a non-empty remote_runner_name."
  }
}

locals {
  module_prefix = "iac-drift-detective"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name          = "iac-drift-detective${local.suffix}"
  workflow_name       = "iac-drift-remediation${local.suffix}"
  sop_drift_scan_name = "iac-drift-scan${local.suffix}"

  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  aws_integration_name    = "${local.module_prefix}-aws${local.suffix}"

  provision_github = trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) == ""
  provision_aws    = trimspace(var.aws_secret_id) != "" && trimspace(var.existing_aws_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
}

module "remote_runner" {
  count  = trimspace(var.remote_runner_name) != "" ? 1 : 0
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = trimspace(var.remote_runner_name)
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_name} (terraform plan / drift scan behind the customer firewall)."
  labels        = var.remote_runner_labels
}

resource "sg_agent" "iac_drift_detective" {
  name           = local.agent_name
  persona        = file("${path.module}/personas/drift-detective.md")
  model_names    = compact(var.model_names)
  remote_runners = var.remote_runner_attach_to_agent && length(module.remote_runner) > 0 ? toset([module.remote_runner[0].runner_name]) : null
  integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_aws_integration_name,
  ])
}

resource "sg_runbook_sop" "drift_scan" {
  name        = local.sop_drift_scan_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/drift-scan.md", {}))
}

resource "sg_workflow" "drift_remediation" {
  name        = local.workflow_name
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
