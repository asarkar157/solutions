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

locals {
  template_vars = {
    max_iterations           = var.max_iterations
    remote_runner_block      = var.remote_runner_block
    module_prefix            = var.module_prefix
    suffix                   = var.suffix
    ubuntu_tool_prefix       = var.ubuntu_tool_prefix
    github_tool_prefix       = var.github_tool_prefix
    aws_tool_prefix          = var.aws_tool_prefix
    stackgen_mcp_tool_prefix = var.stackgen_mcp_tool_prefix
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
