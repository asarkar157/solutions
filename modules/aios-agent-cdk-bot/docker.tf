locals {
  runner_image_repository = trimspace(var.runner_docker_image_repository) != "" ? trimspace(var.runner_docker_image_repository) : "cdk-bot-runner"
  runner_image_tag        = trimspace(var.runner_docker_image_tag) != "" ? trimspace(var.runner_docker_image_tag) : local.script_pack_version
  runner_docker_image     = "${local.runner_image_repository}:${local.runner_image_tag}"

  runner_docker_build_context = path.module
  runner_dockerfile_path      = "${path.module}/docker/Dockerfile"

  build_cdk_runner_image = var.build_runner_image
}

# Builds the CDK-focused aiden-runner image locally during `tofu apply`.
# Requires Docker on the apply host.
resource "null_resource" "cdk_bot_runner_image" {
  count = local.build_cdk_runner_image ? 1 : 0

  triggers = {
    dockerfile          = filemd5(local.runner_dockerfile_path)
    aiden_runner_image  = var.aiden_runner_base_image
    runner_docker_image = local.runner_docker_image
  }

  provisioner "local-exec" {
    command = join(" ", [
      "docker", "build",
      "-t", local.runner_docker_image,
      "--build-arg", "AIDEN_RUNNER_IMAGE=${var.aiden_runner_base_image}",
      "--build-arg", "SCRIPT_PACK_VERSION=${local.script_pack_version}",
      "-f", local.runner_dockerfile_path,
      local.runner_docker_build_context,
    ])
  }
}

locals {
  runner_docker_image_built = local.build_cdk_runner_image ? local.runner_docker_image : ""

  # Image ENTRYPOINT is `aiden-runner start` — pass registration flags after the image name.
  remote_runner_docker_run_command = (
    var.create_remote_runner
    ) ? trimspace(join(" ", compact([
      "docker run -d",
      "--name ${local.resolved_remote_runner_name}",
      "--restart unless-stopped",
      local.runner_docker_image,
      "--runner-token", module.remote_runner.runner_token,
      "--mothership", module.remote_runner.mothership_url,
      "--auto-discover",
      module.remote_runner.sync_cli_args,
  ]))) : ""
}
