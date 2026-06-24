variable "model_names" {
  description = "Ordered list of registered model names for the orchestrator agent."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Map of policy IDs to attach to the orchestrator agent."
  type = object({
    dangerous_ops     = string
    spec_traceability = optional(string, "")
  })
}

variable "policy_create_flags" {
  description = "Plan-time flags from module.policies.policy_create_flags. Drives count on optional policy attachments."
  type = object({
    spec_traceability = optional(bool, true)
  })
  default = {}
}

variable "name_suffix" {
  description = "Optional suffix for agent, workflow, and webhook resource names."
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub PAT for clone, gh api, issue comments, and PR creation on the remote runner."
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_secret_id" {
  description = "Pre-existing sg_secret ID with GIT_TOKEN/GH_TOKEN for runner sync. Mutually exclusive with github_token."
  type        = string
  default     = ""
}

variable "runner_work_home" {
  description = "Home directory on the remote runner host. Pack path is <runner_work_home>/.spec-symphony/pack/<version>/."
  type        = string
  default     = "/home/runner"
}

variable "build_runner_image" {
  description = "Run docker build during apply to bake the script pack into the spec-symphony runner image. Set false when pulling the CI-built GHCR image (see README)."
  type        = bool
  default     = true
}

variable "runner_docker_image_repository" {
  description = "Docker image repository. Use ghcr.io/appcd-dev/solutions-spec-symphony-runner when build_runner_image=false."
  type        = string
  default     = "spec-symphony-runner"
}

variable "runner_docker_image_tag" {
  description = "Docker image tag. Defaults to script_pack_version when empty."
  type        = string
  default     = ""
}

variable "aiden_runner_base_image" {
  description = "Base aiden-runner image for Docker build-arg AIDEN_RUNNER_IMAGE."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-aiden-runner:main"
}

variable "remote_runner_name" {
  description = "Guild remote runner name. Defaults to spec-symphony-runner[-suffix]."
  type        = string
  default     = ""
}

variable "create_remote_runner" {
  description = "When true, creates sg_remote_runner via nested aios-remote-runner."
  type        = bool
  default     = true
}

variable "remote_runner_description" {
  description = "Description for the remote runner when create_remote_runner is true."
  type        = string
  default     = ""
}

variable "remote_runner_attach_to_agent" {
  description = "Attach remote runner to the orchestrator agent."
  type        = bool
  default     = true
}

variable "remote_runner_labels" {
  description = "Labels for sg_remote_runner."
  type        = map(string)
  default     = {}
}

variable "remote_runner_secret_sync_enabled" {
  description = "Enable generic secret sync on the remote runner."
  type        = bool
  default     = true
}

variable "remote_runner_generic_secret_ref_ids" {
  description = "Additional generic secret ref IDs for the remote runner."
  type        = list(string)
  default     = []
}

variable "remote_runner_secrets_sync_interval_seconds" {
  description = "Secrets sync interval for the remote runner."
  type        = number
  default     = 60
}

variable "runner_script_pack_env_secret_id" {
  description = "Pre-existing secret ID for SPECSYM_SCRIPT_PACK_* env sync. Used when create_remote_runner is false."
  type        = string
  default     = ""
}

variable "auto_approve_integration_tools" {
  description = "Auto-approve remote runner execute_* tools on the orchestrator agent."
  type        = bool
  default     = true
}

variable "webhook_trigger_base_url" {
  description = "StackGen tenant base URL for webhook trigger URL outputs (no trailing slash)."
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = "Optional org/project ID appended to webhook trigger URLs."
  type        = string
  default     = ""
}

variable "linear_webhook_allowed_cidrs" {
  description = "IP allowlist for Linear webhook receiver. Empty uses Linear published egress IPs."
  type        = list(string)
  default = [
    "35.231.147.226/32",
    "35.243.134.228/32",
    "34.140.253.14/32",
    "34.38.87.206/32",
    "34.134.222.122/32",
    "35.222.25.142/32",
  ]
}

variable "sdd_framework" {
  description = <<-EOT
    Target spec-driven-development framework the factory bootstraps and authors against. One of:
      - spec-kit: GitHub's Spec Kit layout (specs/ with spec.md, plan.md, tasks.md per feature).
      - openspec: OpenSpec change-proposal layout (openspec/changes/<change>/ with proposal + tasks).
      - ai-dlc:   AWS AI-DLC layout (aidlc-docs/<feature-id>/ with inception.md, construction.md, operations.md).
                  Seeds awslabs/aidlc-workflows rules (.aidlc-rule-details/, AGENTS.md or .cursor/rules/ai-dlc-workflow.mdc).
                  Rules version: aidlc_rules_version (fetched at apply, not vendored in git).
      - auto:     discover which framework the repo already uses from its directory layout; falls back to a sensible default when neither is present.
  EOT
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["spec-kit", "openspec", "ai-dlc", "auto"], var.sdd_framework)
    error_message = "sdd_framework must be spec-kit, openspec, ai-dlc, or auto."
  }
}

variable "aidlc_rules_version" {
  description = <<-EOT
    awslabs/aidlc-workflows release tag fetched at apply (e.g. 1.0.0 or v1.0.0).
    Downloaded into .generated/aidlc-rules for the script pack and runner image when sdd_framework=ai-dlc.
    Not checked into git — bump this to pick up a new upstream AI-DLC rules release.
  EOT
  type        = string
  default     = "1.0.0"
}

variable "change_type" {
  description = <<-EOT
    Change-type preset for the SDD Kit starter. Tells the factory how to frame the
    spec, plan, and tasks for the incoming ticket. One of:
      - greenfield: brand-new feature or service with no existing implementation to extend.
      - brownfield: change to an existing codebase (the common case) — extend or modify current behavior.
      - bugfix:     correct incorrect behavior; spec focuses on the defect, reproduction, and regression coverage.
      - refactor:   restructure code without changing external behavior; spec emphasizes equivalence and safety.
      - migration:  move/upgrade between frameworks, versions, or data shapes; spec emphasizes cutover and rollback.
  EOT
  type        = string
  default     = "brownfield"

  validation {
    condition     = contains(["greenfield", "brownfield", "bugfix", "refactor", "migration"], var.change_type)
    error_message = "change_type must be one of: greenfield, brownfield, bugfix, refactor, migration."
  }
}

variable "quality_max_iterations" {
  description = "Max validate-loop-gate GO_BACK cycles before FINISH → create-pr. Guild caps each stage at 5 visits; keep 1 + quality_max_iterations <= 4 for implement."
  type        = number
  default     = 2

  validation {
    condition     = var.quality_max_iterations >= 1 && var.quality_max_iterations <= 3
    error_message = "quality_max_iterations must be 1–3 (Guild sequential visit cap is 5; implement visits = 1 + quality_max_iterations)."
  }
}

variable "existing_linear_integration_name" {
  description = "Optional existing Linear Guild integration for update-tracker stage (MCP)."
  type        = string
  default     = ""
}

variable "power_pack_refs" {
  description = "Map workflow stage_id to Guild skill_ref names (optional MCP power packs per stage)."
  type        = map(string)
  default     = {}
}

variable "workflow_skill_refs" {
  description = "Optional extra skill_refs per stage. Keys: spec-driven-feature::<stage_id>."
  type        = map(list(string))
  default     = {}
}

variable "implement_engine" {
  description = <<-EOT
    Engine used for the implement stage. One of:
      - shell:      Guild's own LLM drives the implementation and applies edits through the
                    remote runner's shell tools (execute_command / execute_series). No Cursor key needed.
      - cursor_cli: a headless Cursor Agent runs on the remote runner to make the edits.
                    Requires CURSOR_API_KEY on the runner (set cursor_api_key or cursor_secret_id).
  EOT
  type        = string
  default     = "shell"

  validation {
    condition     = contains(["shell", "cursor_cli"], var.implement_engine)
    error_message = "implement_engine must be shell or cursor_cli."
  }
}

variable "cursor_api_key" {
  description = "Cursor API key for runner CURSOR_API_KEY sync when implement_engine=cursor_cli."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cursor_secret_id" {
  description = "Pre-existing sg_secret ID with CURSOR_API_KEY. Mutually exclusive with cursor_api_key."
  type        = string
  default     = ""
}

variable "require_tracker_label" {
  description = "When true, central teams should gate webhooks with a spec-symphony label (documented in SPEC_SYMPHONY.md — not enforced in Terraform)."
  type        = bool
  default     = false
}

variable "linear_product_spec_label" {
  description = "Linear label required on product tickets to run linear-product-spec workflow."
  type        = string
  default     = "needs-spec"
}

variable "linear_implement_label" {
  description = "Linear label that triggers linear-spec-implement (spec blessed)."
  type        = string
  default     = "spec-blessed"
}

variable "enable_linear_product_spec_workflow" {
  description = "When true and existing_linear_integration_name is set, deploy linear-product-spec workflow + webhook."
  type        = bool
  default     = true
}

variable "enable_linear_implement_workflow" {
  description = "When true and existing_linear_integration_name is set, deploy linear-spec-implement workflow + webhook."
  type        = bool
  default     = true
}

variable "linear_implement_engine" {
  description = <<-EOT
    Implement engine for the linear-spec-implement workflow only (the GitHub factory uses
    implement_engine instead). One of:
      - shell:      Guild's LLM applies edits via the remote runner's shell tools. No Cursor key needed.
      - cursor_cli: a headless Cursor Agent runs on the runner. Requires CURSOR_API_KEY on the runner.
  EOT
  type        = string
  default     = "cursor_cli"

  validation {
    condition     = contains(["shell", "cursor_cli"], var.linear_implement_engine)
    error_message = "linear_implement_engine must be shell or cursor_cli."
  }
}

variable "auto_approve_linear_tools" {
  description = "Auto-approve Linear MCP tools on the orchestrator agent."
  type        = bool
  default     = true
}

variable "enable_legacy_linear_factory_webhook" {
  description = "When true, keep linear_receiver webhook targeting spec-driven-feature (legacy monolithic factory)."
  type        = bool
  default     = false
}
