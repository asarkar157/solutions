terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.23, < 0.2.0"
    }
  }
}

locals {
  runner_name = trimspace(var.name)
}

resource "sg_remote_runner" "this" {
  count = var.create_runner ? 1 : 0

  name        = local.runner_name
  description = trimspace(var.description)
  labels      = length(var.labels) > 0 ? var.labels : null
}

data "sg_remote_runner" "existing" {
  count = var.create_runner ? 0 : 1
  name  = local.runner_name
}

locals {
  runner_id = var.create_runner ? sg_remote_runner.this[0].id : data.sg_remote_runner.existing[0].id
  status    = var.create_runner ? sg_remote_runner.this[0].status : data.sg_remote_runner.existing[0].status
}
