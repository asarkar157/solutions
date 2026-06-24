package policy

default approval_required := false

# GitHub fix-PR path (datadog-aws-rca / grafana-github-rca demo gate).
approval_required if {
	github_mutating_tool(input.tool.name)
}

github_mutating_tool(name) if contains(name, "create_pull_request")
github_mutating_tool(name) if contains(name, "create_or_update_file")
github_mutating_tool(name) if contains(name, "merge_pull_request")
github_mutating_tool(name) if contains(name, "update_pull_request")
github_mutating_tool(name) if contains(name, "push_files")
github_mutating_tool(name) if contains(name, "delete_file")

# Datadog writeback / monitor mutation.
datadog_mutating_marker(name) if contains(name, "create_datadog_event")
datadog_mutating_marker(name) if contains(name, "create_datadog_monitor")
datadog_mutating_marker(name) if contains(name, "update_datadog_monitor")
datadog_mutating_marker(name) if contains(name, "delete_datadog")
datadog_mutating_marker(name) if contains(name, "mute_datadog")

approval_required if {
	datadog_mutating_marker(input.tool.name)
}

# Grafana alert rule mutation.
approval_required if {
	grafana_mutating_tool(input.tool.name)
}

grafana_mutating_tool(name) if contains(name, "create_alert")
grafana_mutating_tool(name) if contains(name, "update_alert")
grafana_mutating_tool(name) if contains(name, "delete_alert")
grafana_mutating_tool(name) if contains(name, "silence")

# Shell / remote-runner destructive ops (subset of dangerous-ops).
approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(object.get(input.tool.arguments, "command", ""))
	destructive_shell(cmd)
}

approval_required if {
	endswith(input.tool.name, "_execute_series")
	cmd := lower(object.get(input.tool.arguments, "command", ""))
	destructive_shell(cmd)
}

destructive_shell(cmd) if contains(cmd, "rm -rf")
destructive_shell(cmd) if contains(cmd, "force-delete")
destructive_shell(cmd) if contains(cmd, "terraform destroy")
destructive_shell(cmd) if contains(cmd, "tofu destroy")
destructive_shell(cmd) if contains(cmd, "kubectl delete")
destructive_shell(cmd) if contains(cmd, "kubectl apply")
destructive_shell(cmd) if contains(cmd, "helm uninstall")
destructive_shell(cmd) if contains(cmd, "helm delete")
destructive_shell(cmd) if contains(cmd, "aws ec2 terminate")
destructive_shell(cmd) if contains(cmd, "git push")
destructive_shell(cmd) if contains(cmd, "gh pr create")
destructive_shell(cmd) if contains(cmd, "gh pr merge")
destructive_shell(cmd) if {
	contains(cmd, "gh api repos/")
	contains(cmd, "/pulls")
}

destructive_shell(cmd) if {
	contains(cmd, "api.datadoghq.com")
	contains(cmd, "/api/v1/events")
}

destructive_shell(cmd) if {
	contains(cmd, "api.datadoghq.com")
	contains(cmd, "/api/v1/series")
}

approval_reason := "SRE investigation write or remediation requires human approval before execution" if {
	approval_required
}
