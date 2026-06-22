locals {
  runner_image_repository = trimspace(var.runner_docker_image_repository) != "" ? trimspace(var.runner_docker_image_repository) : "spec-symphony-runner"
  runner_image_tag        = trimspace(var.runner_docker_image_tag) != "" ? trimspace(var.runner_docker_image_tag) : local.script_pack_version
  runner_docker_image     = "${local.runner_image_repository}:${local.runner_image_tag}"

  runner_docker_build_context = path.module
  runner_dockerfile_path      = "${path.module}/docker/Dockerfile"

  build_spec_symphony_runner_image = var.build_runner_image

  runner_allowed_clis = local.needs_cursor_on_runner ? "bash,sh,sudo,apt-get,apt,git,gh,jq,npm,specify,openspec,agent,cursor" : "bash,sh,sudo,apt-get,apt,git,gh,jq,npm,specify,openspec"
}

resource "null_resource" "spec_symphony_runner_image" {
  count = local.build_spec_symphony_runner_image ? 1 : 0

  triggers = {
    dockerfile              = filemd5(local.runner_dockerfile_path)
    aiden_runner_image      = var.aiden_runner_base_image
    runner_docker_image     = local.runner_docker_image
    implement_engine        = var.implement_engine
    linear_implement_engine = var.linear_implement_engine
    needs_cursor            = local.needs_cursor_on_runner
    scripts_hash            = sha1(join("", [for f in fileset("${path.module}/scripts", "*.sh") : filesha1("${path.module}/scripts/${f}")]))
  }

  provisioner "local-exec" {
    command = join(" ", [
      "docker", "build",
      "-t", local.runner_docker_image,
      "--build-arg", "AIDEN_RUNNER_IMAGE=${var.aiden_runner_base_image}",
      "--build-arg", "SCRIPT_PACK_VERSION=${local.script_pack_version}",
      "--build-arg", "INSTALL_CURSOR_CLI=${local.needs_cursor_on_runner ? "1" : "0"}",
      "--build-arg", "ALLOWED_CLIS=${local.runner_allowed_clis}",
      "-f", local.runner_dockerfile_path,
      local.runner_docker_build_context,
    ])
  }
}

locals {
  remote_runner_docker_run_command = var.create_remote_runner ? trimspace(join(" ", compact([
    "docker run -d",
    "--name ${local.resolved_remote_runner_name}",
    "--restart unless-stopped",
    local.runner_docker_image,
    "--runner-token", module.remote_runner[0].runner_token,
    "--mothership", module.remote_runner[0].mothership_url,
    "--auto-discover",
    module.remote_runner[0].sync_cli_args,
  ]))) : ""
}
