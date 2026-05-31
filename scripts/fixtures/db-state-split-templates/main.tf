terraform {
  required_version = ">= 1.5"
}

variable "max_iterations" {
  type    = number
  default = 5
}

variable "remote_runner_block" {
  type    = string
  default = "ci-smoke-runner-block"
}

variable "module_prefix" {
  type    = string
  default = "db-state-splitter"
}

variable "suffix" {
  type    = string
  default = ""
}

variable "ubuntu_tool_prefix" {
  type    = string
  default = "db-state-splitter-ubuntu"
}

variable "github_tool_prefix" {
  type    = string
  default = "db-state-splitter-github"
}

variable "aws_tool_prefix" {
  type    = string
  default = "db-state-splitter-aws"
}

variable "stackgen_mcp_tool_prefix" {
  type    = string
  default = "stackgen-mcp"
}

variable "stage_runner_script" {
  type    = string
  default = "# ci-smoke stage-runner stub"
}

variable "allocate_manifest_script" {
  type    = string
  default = "# ci-smoke allocate_manifest stub"
}

variable "script_pack_version" {
  type    = string
  default = "20260530.2"
}

variable "script_pack_allocate_sha256" {
  type    = string
  default = "deadbeef"
}

variable "script_pack_runner_sha256" {
  type    = string
  default = "deadbeef"
}

variable "stackgen_project_name_default" {
  type    = string
  default = "74301888-bab0-4af5-a882-2de0a491651f"
}

# Server caps from integrations PR #349 (bulk_add_resources_to_appstack /
# bulk_connect_resources_in_appstack). Chunk sizes stay at or below
# max_resources_per_appstack so most groups fit in one bulk_add call.
variable "bulk_add_resources_max_per_call" {
  type    = number
  default = 100
}

variable "bulk_connect_resources_max_per_call" {
  type    = number
  default = 100
}

variable "bulk_resources_chunk_size" {
  type    = number
  default = 80
}

variable "bulk_connections_chunk_size" {
  type    = number
  default = 50
}

variable "subagent_budgets" {
  type = object({
    script_runner_max_llm_calls                = number
    script_runner_max_tool_iterations          = number
    script_runner_timeout_seconds              = number
    registry_codegen_max_llm_calls             = number
    registry_codegen_max_tool_iterations       = number
    registry_codegen_timeout_seconds           = number
    hcl_hydrate_batch_max_llm_calls            = number
    hcl_hydrate_batch_max_tool_iterations      = number
    hcl_hydrate_batch_timeout_seconds          = number
    appstack_batch_max_llm_calls               = number
    appstack_batch_max_tool_iterations         = number
    appstack_batch_timeout_seconds             = number
    plan_convergence_batch_max_llm_calls       = number
    plan_convergence_batch_max_tool_iterations = number
    plan_convergence_batch_timeout_seconds     = number
    mcp_shell_runner_max_llm_calls             = number
    mcp_shell_runner_max_tool_iterations       = number
    mcp_shell_runner_timeout_seconds           = number
  })
  default = {
    script_runner_max_llm_calls                = 40
    script_runner_max_tool_iterations          = 48
    script_runner_timeout_seconds              = 900
    registry_codegen_max_llm_calls             = 60
    registry_codegen_max_tool_iterations       = 48
    registry_codegen_timeout_seconds           = 900
    hcl_hydrate_batch_max_llm_calls            = 60
    hcl_hydrate_batch_max_tool_iterations      = 48
    hcl_hydrate_batch_timeout_seconds          = 600
    appstack_batch_max_llm_calls               = 55
    appstack_batch_max_tool_iterations         = 48
    appstack_batch_timeout_seconds             = 720
    plan_convergence_batch_max_llm_calls       = 60
    plan_convergence_batch_max_tool_iterations = 48
    plan_convergence_batch_timeout_seconds     = 900
    mcp_shell_runner_max_llm_calls             = 35
    mcp_shell_runner_max_tool_iterations       = 45
    mcp_shell_runner_timeout_seconds           = 600
  }
}

locals {
  template_vars = {
    max_iterations                      = var.max_iterations
    remote_runner_block                 = var.remote_runner_block
    module_prefix                       = var.module_prefix
    suffix                              = var.suffix
    ubuntu_tool_prefix                  = var.ubuntu_tool_prefix
    github_tool_prefix                  = var.github_tool_prefix
    aws_tool_prefix                     = var.aws_tool_prefix
    stackgen_mcp_tool_prefix            = var.stackgen_mcp_tool_prefix
    stage_runner_script                 = var.stage_runner_script
    allocate_manifest_script            = var.allocate_manifest_script
    script_pack_version                 = var.script_pack_version
    script_pack_allocate_sha256         = var.script_pack_allocate_sha256
    script_pack_runner_sha256           = var.script_pack_runner_sha256
    stackgen_project_name_default       = var.stackgen_project_name_default
    subagent_budgets                    = var.subagent_budgets
    bulk_add_resources_max_per_call     = var.bulk_add_resources_max_per_call
    bulk_connect_resources_max_per_call = var.bulk_connect_resources_max_per_call
    bulk_resources_chunk_size           = var.bulk_resources_chunk_size
    bulk_connections_chunk_size         = var.bulk_connections_chunk_size
  }

  rendered_templates = {
    for filename in fileset("${path.module}/templates", "*.md.tftpl") :
    filename => trimspace(templatefile("${path.module}/templates/${filename}", local.template_vars))
  }

  rendered_personas = {
    for filename in fileset("${path.module}/personas", "*.md.tftpl") :
    filename => trimspace(templatefile("${path.module}/personas/${filename}", local.template_vars))
  }
}

output "rendered" {
  value = {
    templates = local.rendered_templates
    personas  = local.rendered_personas
  }
}
