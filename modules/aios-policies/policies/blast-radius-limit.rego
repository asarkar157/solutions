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

max_pods_without_approval := 5
max_nodes_without_approval := 3

# Tighter limits off-hours UTC (fewer people to catch mistakes).
max_pods_off_hours := 3
max_nodes_off_hours := 2

# kubectl scale/rollout restart targeting many replicas requires approval.
approval_required if {
	input.tool.name == "kubectl"
	input.tool.arguments.action in {"scale", "rollout"}
	input.tool.arguments.replicas > max_pods_without_approval
}

# kubectl drain/cordon on multiple nodes requires approval.
approval_required if {
	input.tool.name == "kubectl"
	input.tool.arguments.action in {"drain", "cordon", "taint"}
	input.tool.arguments.node_count > max_nodes_without_approval
}

# Shell commands with broad blast radius indicators require approval.
approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	broad_blast_shell(cmd)
}

broad_blast_shell(cmd) if {
	contains(cmd, "kubectl scale")
	contains(cmd, "--replicas=")
	not contains(cmd, "--replicas=1")
	not contains(cmd, "--replicas=2")
	not contains(cmd, "--replicas=3")
}

broad_blast_shell(cmd) if {
	contains(cmd, "kubectl drain")
	contains(cmd, "--selector")
}

broad_blast_shell(cmd) if {
	contains(cmd, "kubectl delete")
	contains(cmd, "--all")
}

# AWS operations spanning multiple regions require approval.
approval_required if {
	input.tool.name == "aws_cli"
	regions := object.get(input.tool.arguments, "regions", [])
	count(regions) > 1
}

# Off-hours: lower replica/node thresholds than business-hours rules above.
approval_required if {
	off_staff_hours
	input.tool.name == "kubectl"
	input.tool.arguments.action in {"scale", "rollout"}
	input.tool.arguments.replicas > max_pods_off_hours
}

approval_required if {
	off_staff_hours
	input.tool.name == "kubectl"
	input.tool.arguments.action in {"drain", "cordon", "taint"}
	input.tool.arguments.node_count > max_nodes_off_hours
}

approval_reason := "Blast radius exceeds safe threshold — must target ≤ 5 pods / ≤ 3 nodes / single region without approval (≤ 3 pods / ≤ 2 nodes off-hours UTC)" if {
	approval_required
}
