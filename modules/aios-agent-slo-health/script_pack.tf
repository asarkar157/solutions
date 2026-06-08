# Script pack embedded on Ubuntu integration at tofu apply.

data "archive_file" "slo_health_script_pack" {
  type        = "tar.gz"
  source_dir  = "${path.module}/scripts"
  output_path = "${path.module}/.generated/slo-health-script-pack-${sha256(file("${path.module}/scripts/stage-runner.sh"))}.tar.gz"
}

locals {
  ubuntu_integration_home = "/home/integration"
  script_pack_version     = "20260607.2"
  slo_health_pack_dir     = "${local.ubuntu_integration_home}/.slo-health/pack/${local.script_pack_version}"

  script_pack_tarball_b64         = filebase64(data.archive_file.slo_health_script_pack.output_path)
  script_pack_stage_runner_sha256 = sha256(file("${path.module}/scripts/stage-runner.sh"))
  script_pack_commit_pr_sha256    = sha256(file("${path.module}/scripts/commit-openslo-pr.sh"))

  slo_health_install_script_pack_body = trimspace(templatefile("${path.module}/templates/install-script-pack.sh.tftpl", {
    slo_health_pack_dir             = local.slo_health_pack_dir
    script_pack_version             = local.script_pack_version
    script_pack_tarball_b64         = local.script_pack_tarball_b64
    script_pack_stage_runner_sha256 = local.script_pack_stage_runner_sha256
  }))

  slo_health_runner_command_prefix = "export WORK_ROOT='{{work_root}}' REPO_FULL_NAME='${var.openslo_repository_full_name}' BASE_BRANCH='${var.openslo_pr_base_branch}' OPENSLO_PATH_PREFIX='${var.openslo_path_prefix}' && ${local.slo_health_install_script_pack_body}"

  slo_health_commit_pr_command = "${local.slo_health_runner_command_prefix} && \"${local.slo_health_pack_dir}/stage-runner.sh\" commit-openslo-pr"

  slo_health_write_drafts_command = "${local.slo_health_runner_command_prefix} && \"${local.slo_health_pack_dir}/stage-runner.sh\" write-openslo-drafts"

  slo_health_spawn_context_header = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
OpenSLO repo: ${var.openslo_repository_full_name}
Base branch: ${var.openslo_pr_base_branch}
Path prefix: ${var.openslo_path_prefix}
script_pack_version: ${local.script_pack_version}
SLO_HEALTH_PACK_DIR: ${local.slo_health_pack_dir}
Draft YAML root: {{work_root}}/openslo-drafts/
Recycle Ubuntu sidecar after tofu apply when script_pack_version changes.
EOT
}
