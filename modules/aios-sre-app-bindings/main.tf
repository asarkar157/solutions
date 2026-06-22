terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # sg_app resource requires provider >= 0.1.26.
      # sg_sre_alert_webhook requires provider >= 0.1.27.
      version = ">= 0.1.27, < 0.2.0"
    }
  }
}

# Binds Guild integrations to an installed stackgen-sre-app (catalog slug "sre").
# The app must already be installed in the target org before apply.
resource "sg_app" "sre" {
  app_name     = var.app_name
  integrations = local.resolved_integration_names
  config       = local.app_config
}

resource "sg_sre_alert_webhook" "this" {
  for_each = local.alert_webhook_map

  app_name    = var.app_name
  source      = each.value.source
  integration = each.value.integration

  auto_investigate              = each.value.auto_investigate
  classify_mode                 = each.value.classify_mode
  classify_batch_window_seconds = each.value.classify_batch_window_seconds
  classify_bucket_by            = each.value.classify_bucket_by
  classify_critical_bypass      = each.value.classify_critical_bypass
}

resource "sg_agent_policy_attachment" "investigator" {
  for_each = local.investigator_policy_map

  agent_name = var.investigator_agent_name
  policy_id  = each.value
  enabled    = true
}

data "sg_agent" "investigator" {
  count = local.attach_remote_runner ? 1 : 0
  name  = var.investigator_agent_name
}

resource "sg_agent" "investigator" {
  count = local.attach_remote_runner ? 1 : 0

  name         = var.investigator_agent_name
  description  = data.sg_agent.investigator[0].description
  persona      = data.sg_agent.investigator[0].persona
  model_names  = data.sg_agent.investigator[0].model_names
  integrations = data.sg_agent.investigator[0].integrations

  remote_runners = setunion(
    toset(data.sg_agent.investigator[0].remote_runners),
    toset([trimspace(var.remote_runner_name)]),
  )
}
