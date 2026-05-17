package policy

default approval_required := false

# Nanoseconds since epoch for input.timestamp (RFC3339). Undefined when missing/invalid.
factsheet_ts_ns := time.parse_rfc3339_ns(ts) if {
	ts := object.get(input, "timestamp", "")
	ts != ""
}

# Weekend or 22:00–07:59 UTC.
off_staff_hours if {
	ns := factsheet_ts_ns
	time.weekday(ns) in {"Saturday", "Sunday"}
}

off_staff_hours if {
	ns := factsheet_ts_ns
	hour := time.clock(ns)[0]
	utc_low_traffic_hour(hour)
}

utc_low_traffic_hour(h) if h < 8
utc_low_traffic_hour(h) if h >= 22

# Auto-remediation actions require approval.
approval_required if {
	input.tool.name == "runbook_executor"
	input.tool.arguments.action in {"restart", "scale", "failover", "rollback", "drain"}
}

# Off-hours: any runbook executor call requires approval (including diagnostics).
approval_required if {
	input.tool.name == "runbook_executor"
	off_staff_hours
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

approval_reason := "SRE remediation/escalation action requires human approval (all runbook actions require approval off-hours UTC)" if {
	approval_required
}
