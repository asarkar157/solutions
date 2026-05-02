output "policy_create_flags" {
  description = "Effective create_policies booleans (plan-time known). Pass to agent modules so policy attachment counts do not depend on unknown policy IDs."
  value = {
    dangerous_ops            = try(var.create_policies.dangerous_ops, true)
    sre_remediation          = try(var.create_policies.sre_remediation, true)
    hitl_approval_evaluation = try(var.create_policies.hitl_approval_evaluation, true)
    prod_write_gate          = try(var.create_policies.prod_write_gate, true)
    tier0_service_protection = try(var.create_policies.tier0_service_protection, true)
    blast_radius_limit       = try(var.create_policies.blast_radius_limit, true)
    freeze_window            = try(var.create_policies.freeze_window, true)
    data_risk_pii            = try(var.create_policies.data_risk_pii, true)
    post_action_verification = try(var.create_policies.post_action_verification, true)
    azure_tool_governance    = try(var.create_policies.azure_tool_governance, true)
    google_tool_governance   = try(var.create_policies.google_tool_governance, true)
    container_shell_hitl     = try(var.create_policies.container_shell_hitl, true)
  }
}

output "policy_ids" {
  description = "Map of policy logical names to their IDs. Only includes policies that were created."
  value = {
    dangerous_ops            = length(sg_policy.dangerous_ops) > 0 ? sg_policy.dangerous_ops[0].id : ""
    sre_remediation          = length(sg_policy.sre_remediation) > 0 ? sg_policy.sre_remediation[0].id : ""
    hitl_approval_evaluation = length(sg_policy.hitl_approval_evaluation) > 0 ? sg_policy.hitl_approval_evaluation[0].id : ""
    prod_write_gate          = length(sg_policy.prod_write_gate) > 0 ? sg_policy.prod_write_gate[0].id : ""
    tier0_service_protection = length(sg_policy.tier0_service_protection) > 0 ? sg_policy.tier0_service_protection[0].id : ""
    blast_radius_limit       = length(sg_policy.blast_radius_limit) > 0 ? sg_policy.blast_radius_limit[0].id : ""
    freeze_window            = length(sg_policy.freeze_window) > 0 ? sg_policy.freeze_window[0].id : ""
    data_risk_pii            = length(sg_policy.data_risk_pii) > 0 ? sg_policy.data_risk_pii[0].id : ""
    post_action_verification = length(sg_policy.post_action_verification) > 0 ? sg_policy.post_action_verification[0].id : ""
    azure_tool_governance    = length(sg_policy.azure_tool_governance) > 0 ? sg_policy.azure_tool_governance[0].id : ""
    google_tool_governance   = length(sg_policy.google_tool_governance) > 0 ? sg_policy.google_tool_governance[0].id : ""
    container_shell_hitl     = length(sg_policy.container_shell_hitl) > 0 ? sg_policy.container_shell_hitl[0].id : ""
  }
}

output "policy_names" {
  description = "Map of policy logical names to their registered names"
  value = {
    dangerous_ops            = length(sg_policy.dangerous_ops) > 0 ? sg_policy.dangerous_ops[0].name : ""
    sre_remediation          = length(sg_policy.sre_remediation) > 0 ? sg_policy.sre_remediation[0].name : ""
    hitl_approval_evaluation = length(sg_policy.hitl_approval_evaluation) > 0 ? sg_policy.hitl_approval_evaluation[0].name : ""
    prod_write_gate          = length(sg_policy.prod_write_gate) > 0 ? sg_policy.prod_write_gate[0].name : ""
    tier0_service_protection = length(sg_policy.tier0_service_protection) > 0 ? sg_policy.tier0_service_protection[0].name : ""
    blast_radius_limit       = length(sg_policy.blast_radius_limit) > 0 ? sg_policy.blast_radius_limit[0].name : ""
    freeze_window            = length(sg_policy.freeze_window) > 0 ? sg_policy.freeze_window[0].name : ""
    data_risk_pii            = length(sg_policy.data_risk_pii) > 0 ? sg_policy.data_risk_pii[0].name : ""
    post_action_verification = length(sg_policy.post_action_verification) > 0 ? sg_policy.post_action_verification[0].name : ""
    azure_tool_governance    = length(sg_policy.azure_tool_governance) > 0 ? sg_policy.azure_tool_governance[0].name : ""
    google_tool_governance   = length(sg_policy.google_tool_governance) > 0 ? sg_policy.google_tool_governance[0].name : ""
    container_shell_hitl     = length(sg_policy.container_shell_hitl) > 0 ? sg_policy.container_shell_hitl[0].name : ""
  }
}
