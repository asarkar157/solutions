terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.20, < 0.2.0"
    }
  }
}

locals {
  schedules_by_name = { for s in var.schedules : s.name => s }
}

resource "sg_agent_schedule" "this" {
  for_each = local.schedules_by_name

  target_type = var.target_type
  target_name = var.target_name
  name        = each.value.name
  expression  = each.value.expression
  action      = each.value.action
  enabled     = coalesce(each.value.enabled, true)
}
