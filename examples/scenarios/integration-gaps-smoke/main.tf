# =============================================================================
# Scenario: integration-gaps-smoke
# =============================================================================
# Provisions the nine Aiden-2 gap integration types and validates Guild
# connectivity with scripts/test-integrations.sh (POST .../test).
#
# Enable only integrations you have credentials for in terraform.tfvars.

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
  stackgen_url      = var.stackgen_url
  stackgen_token    = var.stackgen_token
  project_id        = var.stackgen_project_id
  insecure          = var.stackgen_insecure
  adopt_on_conflict = true
}

module "kubernetes" {
  count  = var.enable_kubernetes ? 1 : 0
  source = "../../../modules/aios-integration-kubernetes"

  integration_name = "${var.name_prefix}-kubernetes"
  role_arn         = var.kubernetes_role_arn
  region           = var.kubernetes_region
  cluster_name     = var.kubernetes_cluster_name
}

module "sonarqube" {
  count  = var.enable_sonarqube ? 1 : 0
  source = "../../../modules/aios-integration-sonarqube"

  integration_name = "${var.name_prefix}-sonarqube"
  server_url       = var.sonarqube_server_url
  token            = var.sonarqube_token
}

module "firehydrant" {
  count  = var.enable_firehydrant ? 1 : 0
  source = "../../../modules/aios-integration-firehydrant"

  integration_name = "${var.name_prefix}-firehydrant"
  api_key          = var.firehydrant_api_key
  base_url         = var.firehydrant_base_url
}

module "digitalocean" {
  count  = var.enable_digitalocean ? 1 : 0
  source = "../../../modules/aios-integration-digitalocean"

  integration_name   = "${var.name_prefix}-digitalocean"
  digitalocean_token = var.digitalocean_token
}

module "coralogix" {
  count  = var.enable_coralogix ? 1 : 0
  source = "../../../modules/aios-integration-coralogix"

  integration_name   = "${var.name_prefix}-coralogix"
  coralogix_api_key  = var.coralogix_api_key
  coralogix_base_url = var.coralogix_base_url
}

module "civo" {
  count  = var.enable_civo ? 1 : 0
  source = "../../../modules/aios-integration-civo"

  integration_name = "${var.name_prefix}-civo"
  civo_api_key     = var.civo_api_key
}

module "newrelic" {
  count  = var.enable_newrelic ? 1 : 0
  source = "../../../modules/aios-integration-newrelic"

  integration_name = "${var.name_prefix}-newrelic"
  newrelic_api_key = var.newrelic_api_key
  newrelic_region  = var.newrelic_region
}

module "circleci" {
  count  = var.enable_circleci ? 1 : 0
  source = "../../../modules/aios-integration-circleci"

  integration_name = "${var.name_prefix}-circleci"
  circleci_token   = var.circleci_token
}

module "squadcast" {
  count  = var.enable_squadcast ? 1 : 0
  source = "../../../modules/aios-integration-squadcast"

  integration_name        = "${var.name_prefix}-squadcast"
  squadcast_refresh_token = var.squadcast_refresh_token
  squadcast_region        = var.squadcast_region
}

locals {
  integration_names = compact([
    var.enable_kubernetes ? module.kubernetes[0].integration_name : "",
    var.enable_sonarqube ? module.sonarqube[0].integration_name : "",
    var.enable_firehydrant ? module.firehydrant[0].integration_name : "",
    var.enable_digitalocean ? module.digitalocean[0].integration_name : "",
    var.enable_coralogix ? module.coralogix[0].integration_name : "",
    var.enable_civo ? module.civo[0].integration_name : "",
    var.enable_newrelic ? module.newrelic[0].integration_name : "",
    var.enable_circleci ? module.circleci[0].integration_name : "",
    var.enable_squadcast ? module.squadcast[0].integration_name : "",
  ])
}
