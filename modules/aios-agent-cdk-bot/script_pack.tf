# Script pack tarball at tofu apply — synced to remote runner via generic vault secret (no Docker rebuild per script change).

data "archive_file" "cdkbot_script_pack" {
  type        = "tar.gz"
  source_dir  = "${path.module}/scripts"
  output_path = "${path.module}/.generated/cdkbot-script-pack-${sha256(file("${path.module}/scripts/stage-runner.sh"))}.tar.gz"
}

locals {
  script_pack_tarball_b64              = filebase64(data.archive_file.cdkbot_script_pack.output_path)
  script_pack_tarball_sha256           = filesha256(data.archive_file.cdkbot_script_pack.output_path)
  create_runner_script_pack_env_secret = var.create_remote_runner
  runner_script_pack_env_secret_id     = local.create_runner_script_pack_env_secret ? sg_secret.runner_script_pack_env[0].id : trimspace(var.runner_script_pack_env_secret_id)
  runner_generic_secret_ref_ids = var.remote_runner_secret_sync_enabled ? compact(concat(
    var.remote_runner_generic_secret_ref_ids,
    trimspace(local.runner_script_pack_env_secret_id) != "" ? [local.runner_script_pack_env_secret_id] : [],
  )) : []
  runner_script_pack_env_json = jsonencode({
    CDKBOT_SCRIPT_PACK_VERSION        = local.script_pack_version
    CDKBOT_SCRIPT_PACK_TARBALL_B64    = local.script_pack_tarball_b64
    CDKBOT_SCRIPT_PACK_TARBALL_SHA256 = local.script_pack_tarball_sha256
    CDKBOT_CLONE_PACK_SHA256          = local.script_pack_clone_sha256
    CDKBOT_STAGE_RUNNER_SHA256        = local.script_pack_runner_sha256
  })
  cdkbot_pack_ensure_shell_body = trimspace(replace(
    templatefile("${path.module}/templates/cdkbot-pack-ensure-shell.sh.tftpl", {
      cdkbot_pack_dir           = local.cdkbot_pack_dir
      script_pack_version       = local.script_pack_version
      script_pack_runner_sha256 = local.script_pack_runner_sha256
      script_pack_clone_sha256  = local.script_pack_clone_sha256
      pack_missing_hint         = "tofu_apply_and_restart_aiden_runner_for_secrets_sync"
    }),
    "\n",
    " ",
  ))
}

resource "sg_secret" "runner_script_pack_env" {
  count = local.create_runner_script_pack_env_secret ? 1 : 0

  name        = "${local.module_prefix}-runner-script-pack-env${local.suffix}"
  description = "Terraform-baked CDK bot script pack tarball for ${local.resolved_remote_runner_name} (mothership generic secret sync)."
  category    = "Provider"
  subcategory = "generic"
  metadata = {
    value = local.runner_script_pack_env_json
  }
}
