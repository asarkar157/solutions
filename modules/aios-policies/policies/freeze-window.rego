package policy

default allow := true

change_actions := {"deploy", "apply", "release", "config_update", "feature_flag_toggle", "helm_upgrade", "rollout"}

# Nanoseconds since epoch for input.timestamp (RFC3339). Undefined when missing/invalid.
factsheet_ts_ns := time.parse_rfc3339_ns(ts) if {
	ts := object.get(input, "timestamp", "")
	ts != ""
}

# Monday–Friday, 09:00–17:59 UTC (from input.timestamp). Adjust here or move
# bounds to policy_data when your stack wires configurable windows.
during_business_hours if {
	ns := factsheet_ts_ns
	time.weekday(ns) in {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday"}
	hour := time.clock(ns)[0]
	hour >= 9
	hour < 18
}

# Change actions during business hours are denied.
allow := false if {
	during_business_hours
	input.tool.arguments.action in change_actions
}

# Shell commands that perform deployments or config changes during business hours are denied.
allow := false if {
	during_business_hours
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	deploy_shell_pattern(cmd)
}

deploy_shell_pattern(cmd) if contains(cmd, "terraform apply")
deploy_shell_pattern(cmd) if contains(cmd, "tofu apply")
deploy_shell_pattern(cmd) if contains(cmd, "kubectl apply")
deploy_shell_pattern(cmd) if contains(cmd, "kubectl set image")
deploy_shell_pattern(cmd) if contains(cmd, "kubectl rollout")
deploy_shell_pattern(cmd) if contains(cmd, "helm install")
deploy_shell_pattern(cmd) if contains(cmd, "helm upgrade")
deploy_shell_pattern(cmd) if contains(cmd, "argocd app sync")
deploy_shell_pattern(cmd) if contains(cmd, "git push")

# Terraform apply/destroy during business hours is denied.
allow := false if {
	during_business_hours
	input.tool.name == "terraform"
	input.tool.arguments.command in {"apply", "destroy"}
}

# Helm install/upgrade/rollback during business hours is denied.
allow := false if {
	during_business_hours
	input.tool.name == "helm"
	input.tool.arguments.action in {"install", "upgrade", "rollback"}
}

deny_reason := "Change freeze: production-impacting changes are blocked during business hours (Mon–Fri, 09:00–17:59 UTC per input.timestamp). Retry outside that window or route through your CAB process." if {
	not allow
}
