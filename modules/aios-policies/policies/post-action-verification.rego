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

rollout_actions := {"rollout_proceed", "canary_promote", "traffic_shift_expand", "scale_up_global"}

# Shell commands that promote or expand a rollout require approval.
approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	rollout_shell_pattern(cmd)
}

rollout_shell_pattern(cmd) if {
	contains(cmd, "kubectl rollout")
	not contains(cmd, "status")
	not contains(cmd, "history")
}

rollout_shell_pattern(cmd) if {
	contains(cmd, "argocd app sync")
	contains(cmd, "prod")
}

rollout_shell_pattern(cmd) if {
	contains(cmd, "kubectl scale")
	contains(cmd, "prod")
}

# Off-hours: any Argo CD sync via shell needs explicit approval (not only prod).
approval_required if {
	off_staff_hours
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	contains(cmd, "argocd app sync")
}

# Structured tool calls for broader rollout require approval.
approval_required if {
	input.tool.arguments.action in rollout_actions
}

# Helm upgrade in production after initial canary requires approval.
approval_required if {
	input.tool.name == "helm"
	input.tool.arguments.action in {"upgrade", "rollback"}
	input.tool.arguments.namespace in {"production", "prod"}
}

approval_reason := "Broader rollout, production Helm change, or off-hours GitOps sync requires owner approval before proceeding" if {
	approval_required
}
