terraform {
  required_version = ">= 1.5"
}

locals {
  module_prefix           = "terraform-bot"
  ubuntu_tool_prefix      = "terraform-bot-ubuntu"
  ubuntu_integration_home = "/home/integration"
  script_pack_version     = "20260531.37"
  tfbot_pack_dir          = "${local.ubuntu_integration_home}/.terraform-bot/pack/${local.script_pack_version}"
  stage_runner_script     = trimspace(file("${path.module}/scripts/stage-runner.sh"))
}

output "rendered_script_pack" {
  value = trimspace(templatefile("${path.module}/templates/workflow-script-pack.md.tftpl", {
    ubuntu_tool_prefix      = local.ubuntu_tool_prefix
    ubuntu_integration_home = local.ubuntu_integration_home
    script_pack_version     = local.script_pack_version
    tfbot_pack_dir          = local.tfbot_pack_dir
  }))
}

output "stage_runner_lines" {
  value = length(split("\n", local.stage_runner_script))
}
