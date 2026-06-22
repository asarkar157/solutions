# =============================================================================
# Scenario: sre-boost
# =============================================================================
# Attach new GitHub + AWS integrations and an on-prem remote runner to an
# existing Guild agent. Does not register models or create agents.
# See ./README.md for import steps and the talk track.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

data "sg_vault_aws_config" "workspace" {
  org_id = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

locals {
  agent_name = trimspace(var.agent_name)
  enable_aws = trimspace(var.aws_role_arn) != ""

  boost_integrations = setunion(
    toset([module.github_integration.integration_name]),
    local.enable_aws ? toset([module.aws_integration[0].integration_name]) : toset([]),
    var.enable_ubuntu_kubectl ? toset([module.ubuntu_integration[0].integration_name]) : toset([]),
  )

  runner_typed_secret_refs = var.create_remote_runner ? merge(
    { github = module.github_integration.secret_id },
    local.enable_aws ? { aws = module.aws_integration[0].secret_id } : {},
  ) : {}

  # Image ENTRYPOINT is `aiden-runner start` — pass registration flags after the image name.
  remote_runner_docker_run_command = var.create_remote_runner ? trimspace(join(" ", compact([
    "docker run -d",
    "--name ${module.remote_runner.runner_name}",
    "--restart unless-stopped",
    var.runner_docker_image,
    "--runner-token", module.remote_runner.runner_token,
    "--mothership", module.remote_runner.mothership_url,
    "--auto-discover",
    module.remote_runner.sync_cli_args,
  ]))) : ""
}

module "github_integration" {
  source = "../../../modules/aios-integration-github"

  integration_name = "sre-boost-github"
  github_token     = var.github_token
}

module "aws_integration" {
  count  = local.enable_aws ? 1 : 0
  source = "../../../modules/aios-integration-aws"

  integration_name = "sre-boost-aws"
  aws_role_arn     = var.aws_role_arn
  aws_region       = var.aws_region
}

module "remote_runner" {
  source = "../../../modules/aios-remote-runner"

  create_runner     = var.create_remote_runner
  name              = var.remote_runner_name
  description       = "On-prem shell runner for ${local.agent_name} (git, kubectl, customer-network diagnostics)."
  typed_secret_refs = local.runner_typed_secret_refs
}

module "ubuntu_integration" {
  count  = var.enable_ubuntu_kubectl ? 1 : 0
  source = "../../../modules/aios-integration-ubuntu"

  integration_name = "sre-boost-ubuntu-kubectl"
  install_tools    = ["kubectl", "curl", "jq", "gh"]
}

data "sg_agent" "target" {
  name = local.agent_name
}

resource "sg_agent" "sre_boost" {
  name        = local.agent_name
  description = data.sg_agent.target.description
  persona     = data.sg_agent.target.persona
  model_names = data.sg_agent.target.model_names

  integrations = setunion(
    toset(data.sg_agent.target.integrations),
    local.boost_integrations,
  )

  remote_runners = var.create_remote_runner ? setunion(
    toset(data.sg_agent.target.remote_runners),
    toset([module.remote_runner.runner_name]),
  ) : toset(data.sg_agent.target.remote_runners)
}
