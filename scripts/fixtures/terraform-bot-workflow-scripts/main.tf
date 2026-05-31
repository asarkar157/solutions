terraform {
  required_version = ">= 1.5"
}

locals {
  module_prefix       = "terraform-bot"
  ubuntu_tool_prefix  = "terraform-bot-ubuntu"
  stage_runner_script = trimspace(file("${path.module}/scripts/stage-runner.sh"))
}

output "rendered_script_pack" {
  value = trimspace(templatefile("${path.module}/templates/workflow-script-pack.md.tftpl", {
    ubuntu_tool_prefix  = local.ubuntu_tool_prefix
    stage_runner_script = local.stage_runner_script
  }))
}

output "stage_runner_lines" {
  value = length(split("\n", local.stage_runner_script))
}
