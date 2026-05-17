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

prod_namespaces := {"production", "prod"}

# Shell commands targeting production environments require approval.
approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	prod_shell_pattern(cmd)
}

prod_shell_pattern(cmd) if {
	contains(cmd, "terraform apply")
	contains(cmd, "prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "tofu apply")
	contains(cmd, "prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "kubectl apply")
	contains(cmd, "-n prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "kubectl delete")
	contains(cmd, "-n prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "kubectl scale")
	contains(cmd, "-n prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "kubectl set")
	contains(cmd, "-n prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "kubectl patch")
	contains(cmd, "-n prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "kubectl rollout")
	contains(cmd, "-n prod")
	not contains(cmd, "rollout status")
	not contains(cmd, "rollout history")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "kubectl")
	contains(cmd, "--namespace prod")
	kubectl_write_action(cmd)
}

kubectl_write_action(cmd) if contains(cmd, "apply")
kubectl_write_action(cmd) if contains(cmd, "delete")
kubectl_write_action(cmd) if contains(cmd, "scale")
kubectl_write_action(cmd) if contains(cmd, "patch")
kubectl_write_action(cmd) if contains(cmd, "set ")

prod_shell_pattern(cmd) if {
	contains(cmd, "helm install")
	contains(cmd, "-n prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "helm upgrade")
	contains(cmd, "-n prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "helm rollback")
	contains(cmd, "-n prod")
}

prod_shell_pattern(cmd) if {
	contains(cmd, "aws")
	contains(cmd, "--profile prod")
}

# kubectl/helm write actions in production namespaces require approval.
approval_required if {
	input.tool.name in {"kubectl", "helm"}
	input.tool.arguments.namespace in prod_namespaces
	input.tool.arguments.action in {"apply", "create", "delete", "scale", "patch", "edit", "replace", "install", "upgrade", "rollback", "restart"}
}

# AWS mutations tagged as production require approval.
approval_required if {
	input.tool.name == "aws_cli"
	input.tool.arguments.action in {"create", "modify", "delete", "terminate", "update", "put"}
	input.tool.arguments.environment in prod_namespaces
}

# Terraform/OpenTofu apply targeting a prod workspace requires approval.
approval_required if {
	input.tool.name == "terraform"
	input.tool.arguments.command in {"apply", "destroy"}
	input.tool.arguments.workspace in prod_namespaces
}

# Runbook executor actions in production require approval.
approval_required if {
	input.tool.name == "runbook_executor"
	input.tool.arguments.environment in prod_namespaces
}

# Terraform destroy is high impact — require approval off-hours even for non-prod workspaces.
approval_required if {
	input.tool.name == "terraform"
	input.tool.arguments.command == "destroy"
	off_staff_hours
}

# PagerDuty escalation always requires owner/on-call acknowledgement.
approval_required if {
	input.tool.name == "pagerduty"
	input.tool.arguments.action in {"escalate", "reassign"}
}

approval_reason := "Production write or off-hours Terraform destroy requires service-owner or on-call acknowledgement" if {
	approval_required
}
