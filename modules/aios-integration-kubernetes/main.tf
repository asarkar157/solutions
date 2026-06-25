terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.role_arn) != "" && trimspace(var.cluster_name) != ""
  secret_id     = local.create_secret ? sg_secret.kubernetes_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || (trimspace(var.role_arn) != "" && trimspace(var.cluster_name) != "" && trimspace(var.region) != "")
      error_message = "aios-integration-kubernetes requires `existing_secret_id` or `role_arn`, `region`, and `cluster_name`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && trimspace(var.role_arn) != "")
      error_message = "aios-integration-kubernetes cannot accept both `existing_secret_id` and inline EKS credentials."
    }
  }
}

resource "sg_secret" "kubernetes_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "EKS kubectl credentials for ${var.integration_name}"
  category    = "Cloud"
  subcategory = "kubernetes"
  metadata = {
    role_arn     = var.role_arn
    region       = var.region
    cluster_name = var.cluster_name
  }
}

resource "sg_guild_integration" "kubernetes" {
  name           = var.integration_name
  description    = var.description
  type           = "kubernetes"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
