# Script pack embedded on Ubuntu integration at tofu apply — runners must not git-clone tooling repos.

data "archive_file" "cfn_author_script_pack" {
  type        = "tar.gz"
  source_dir  = "${path.module}/scripts"
  output_path = "${path.module}/.generated/cfn-author-script-pack-${sha256(file("${path.module}/scripts/stage-runner.sh"))}.tar.gz"
}

locals {
  ubuntu_integration_home = "/home/integration"
  script_pack_version     = "20260608.4"
  cfn_author_pack_dir     = "${local.ubuntu_integration_home}/.cfn-author/pack/${local.script_pack_version}"

  script_pack_tarball_b64         = filebase64(data.archive_file.cfn_author_script_pack.output_path)
  script_pack_stage_runner_sha256 = sha256(file("${path.module}/scripts/stage-runner.sh"))
  script_pack_guardrails_sha256   = sha256(file("${path.module}/scripts/security-guardrails.sh"))
  script_pack_commit_pr_sha256    = sha256(file("${path.module}/scripts/commit-and-pr.sh"))

  cfn_author_install_script_pack_body = trimspace(templatefile("${path.module}/templates/install-script-pack.sh.tftpl", {
    script_pack_version             = local.script_pack_version
    cfn_author_pack_dir             = local.cfn_author_pack_dir
    script_pack_stage_runner_sha256 = local.script_pack_stage_runner_sha256
    script_pack_guardrails_sha256   = local.script_pack_guardrails_sha256
    script_pack_commit_pr_sha256    = local.script_pack_commit_pr_sha256
  }))

  cfn_author_runner_command_prefix = "export WORK_ROOT='{{work_root}}' REPO_FULL_NAME='${local.resolved_workspace.repository_full_name}' BASE_BRANCH='${local.resolved_workspace.base_branch}' TEMPLATE_PREFIX='${local.resolved_workspace.path_prefix}' WORKSPACE_ID='${local.resolved_workspace.workspace_id}' FEDRAMP_PROFILE='${var.fedramp_profile}' CFN_AUTHOR_HIGH_RPS_THRESHOLD='${var.architecture_lint_high_rps_threshold}' CFN_AUTHOR_MAX_TEMPLATE_LINES='${var.max_template_lines}' && ${local.cfn_author_install_script_pack_body}"

  cfn_author_parse_requirements_command = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" parse-requirements"
  cfn_author_parse_intent_once_command  = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" parse-intent-once"
  cfn_author_render_summary_command     = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" render-final-summary"
  cfn_author_architecture_lint_command  = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" architecture-lint"
  cfn_author_compliance_check_command   = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" compliance-check"
  cfn_author_catalog_discover_command   = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" catalog-discover"
  cfn_author_change_set_preview_command = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" change-set-preview"

  cfn_author_validate_command      = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" validate-template"
  cfn_author_quality_check_command = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" quality-check"
  cfn_author_guardrails_command    = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" security-guardrails"
  cfn_author_commit_pr_command     = "${local.cfn_author_runner_command_prefix} && \"${local.cfn_author_pack_dir}/stage-runner.sh\" commit-pr"

  cfn_author_spawn_context_header = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
Target repo: ${local.resolved_workspace.repository_full_name}
Base branch: ${local.resolved_workspace.base_branch}
Template prefix: ${local.resolved_workspace.path_prefix}
script_pack_version: ${local.script_pack_version}
CFN_AUTHOR_PACK_DIR: ${local.cfn_author_pack_dir}
Recycle Ubuntu sidecar after tofu apply when script_pack_version changes.
EOT
}
