package policy

default approval_required = false

# Auto-remediation actions require approval.
approval_required if {
  input.tool.name == "runbook_executor"
  input.tool.arguments.action in {"restart", "scale", "failover", "rollback", "drain"}
}

# Acknowledging or resolving PagerDuty incidents is allowed; escalation requires approval.
approval_required if {
  input.tool.name == "pagerduty"
  input.tool.arguments.action in {"escalate", "reassign", "snooze"}
}

# Modifying alerting rules requires approval.
approval_required if {
  input.tool.name == "grafana"
  input.tool.arguments.action in {"create_alert", "update_alert", "delete_alert", "silence"}
}

approval_reason = "SRE remediation/escalation action requires human approval" if {
  approval_required
}
