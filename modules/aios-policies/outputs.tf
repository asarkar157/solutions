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
