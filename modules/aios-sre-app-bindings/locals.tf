data "sg_app" "current" {
  count    = var.merge_existing_app_integrations ? 1 : 0
  app_name = var.app_name
}

locals {
  app_config = var.config != null ? var.config : (
    var.enable_discovery_bootstrap ? { setup_type = "workspace" } : null
  )

  existing_app_integration_names = var.merge_existing_app_integrations ? data.sg_app.current[0].integrations : []

  resolved_integration_names = sort(toset(concat(
    local.existing_app_integration_names,
    compact(var.integration_names),
  )))

  alert_webhook_map = {
    for wh in var.alert_webhooks :
    "${wh.source}:${wh.integration}" => wh
  }

  attach_investigator_policies = var.investigator_policy_ids != null
  attach_remote_runner         = trimspace(var.remote_runner_name) != ""

  investigator_policy_candidates = local.attach_investigator_policies ? {
    dangerous_ops                = try(var.investigator_policy_ids.dangerous_ops, "")
    sre_remediation              = try(var.investigator_policy_ids.sre_remediation, "")
    prod_write_gate              = try(var.investigator_policy_ids.prod_write_gate, "")
    sre_investigation_write_gate = try(var.investigator_policy_ids.sre_investigation_write_gate, "")
    pagerduty_escalation_gate    = try(var.investigator_policy_ids.pagerduty_escalation_gate, "")
  } : {}

  investigator_policy_flags = {
    dangerous_ops                = true
    sre_remediation              = try(var.policy_create_flags.sre_remediation, true)
    prod_write_gate              = try(var.policy_create_flags.prod_write_gate, true)
    sre_investigation_write_gate = try(var.policy_create_flags.sre_investigation_write_gate, true)
    pagerduty_escalation_gate    = try(var.policy_create_flags.pagerduty_escalation_gate, true)
  }

  investigator_policy_map = {
    for key, id in local.investigator_policy_candidates :
    key => id
    if trimspace(id) != "" && try(local.investigator_policy_flags[key], true)
  }
}
