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

variable "shell_tool_prefix" {
  type    = string
  default = "db-state-splitter-runner"
}

variable "remote_runner_name" {
  type    = string
  default = "db-state-splitter-runner"
}

variable "runner_work_home" {
  type    = string
  default = "/home/runner"
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
  default = "20260604.5"
}

variable "script_pack_git_ref" {
  type    = string
  default = "main"
}

variable "script_pack_allocate_sha256" {
  type    = string
  default = "deadbeef"
}

variable "script_pack_runner_sha256" {
  type    = string
  default = "deadbeef"
}

variable "script_pack_allocate_b64" {
  type    = string
  default = "IyBjaS1zb2tlIGFsbG9jYXRlX3N0dWI="
}

variable "script_pack_runner_b64" {
  type    = string
  default = "IyBjaS1zb2tlIHJ1bm5lcl9zdHVi"
}

variable "stackgen_project_name_default" {
  type    = string
  default = "guild-demo"
}

variable "default_grouping_strategy" {
  type    = string
  default = "tag_seeded_connectivity"
}

variable "default_max_resources_per_appstack" {
  type    = number
  default = 0
}

variable "default_iac_repository_url" {
  type    = string
  default = ""
}

variable "default_branch" {
  type    = string
  default = "main"
}

variable "subagent_task_type" {
  type    = string
  default = "coding"
}

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
  dbsplit_script_pack_env_helpers = templatefile(
    "${path.module}/templates/dbsplit-script-pack-env.sh.tftpl",
    {
      script_pack_version         = var.script_pack_version
      script_pack_allocate_sha256 = var.script_pack_allocate_sha256
      script_pack_runner_sha256   = var.script_pack_runner_sha256
    },
  )

  # Mirror modules/aios-agent-db-state-splitter/main.tf locals.template_vars.
  template_vars = {
    module_prefix                       = var.module_prefix
    suffix                              = var.suffix
    shell_tool_prefix                   = var.shell_tool_prefix
    remote_runner_name                  = var.remote_runner_name
    github_tool_prefix                  = var.github_tool_prefix
    aws_tool_prefix                     = var.aws_tool_prefix
    stackgen_mcp_tool_prefix            = var.stackgen_mcp_tool_prefix
    max_iterations                      = var.max_iterations
    remote_runner_block                 = var.remote_runner_block
    stage_runner_script                 = var.stage_runner_script
    allocate_manifest_script            = var.allocate_manifest_script
    script_pack_version                 = var.script_pack_version
    script_pack_git_ref                 = var.script_pack_git_ref
    script_pack_allocate_sha256         = var.script_pack_allocate_sha256
    script_pack_runner_sha256           = var.script_pack_runner_sha256
    script_pack_allocate_b64            = var.script_pack_allocate_b64
    script_pack_runner_b64              = var.script_pack_runner_b64
    runner_work_home                    = var.runner_work_home
    stackgen_project_name_default       = var.stackgen_project_name_default
    default_grouping_strategy           = var.default_grouping_strategy
    default_max_resources_per_appstack  = var.default_max_resources_per_appstack
    default_iac_repository_url          = var.default_iac_repository_url
    default_branch                      = var.default_branch
    subagent_budgets                    = var.subagent_budgets
    subagent_task_type                  = var.subagent_task_type
    bulk_add_resources_max_per_call     = var.bulk_add_resources_max_per_call
    bulk_connect_resources_max_per_call = var.bulk_connect_resources_max_per_call
    bulk_resources_chunk_size           = var.bulk_resources_chunk_size
    bulk_connections_chunk_size         = var.bulk_connections_chunk_size
    dbsplit_script_pack_env_helpers     = local.dbsplit_script_pack_env_helpers
  }

  rendered_templates = {
    for filename in fileset("${path.module}/templates", "*.md.tftpl") :
    filename => trimspace(templatefile("${path.module}/templates/${filename}", local.template_vars))
  }

  rendered_personas = {
    for filename in fileset("${path.module}/personas", "*.md.tftpl") :
    filename => trimspace(templatefile("${path.module}/personas/${filename}", local.template_vars))
  }

  rendered_embeds = {
    ingest   = templatefile("${path.module}/templates/ingest-execute-series-embedded.sh.tftpl", local.template_vars)
    iac_pr   = templatefile("${path.module}/templates/iac-pr-execute-series-embedded.sh.tftpl", local.template_vars)
    converge = templatefile("${path.module}/templates/converge-execute-series-embedded.sh.tftpl", local.template_vars)
  }
}

output "rendered" {
  value = {
    templates = local.rendered_templates
    personas  = local.rendered_personas
    embeds    = local.rendered_embeds
  }
}
