package policy

default approval_required := false

approval_required if {
	contains(input.tool.name, "pagerduty")
	action := lower(object.get(input.tool.arguments, "action", ""))
	action in {"escalate", "reassign", "snooze"}
}

approval_reason := "PagerDuty escalation or reassignment requires human approval" if {
	approval_required
}
