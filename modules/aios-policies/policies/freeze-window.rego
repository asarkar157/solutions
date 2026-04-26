package policy

default allow = true

change_actions := {"deploy", "apply", "release", "config_update", "feature_flag_toggle", "helm_upgrade", "rollout"}

# Shell commands that perform deployments or config changes during a freeze are denied.
allow = false if {
	input.context.freeze_window_active == true
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	deploy_shell_pattern(cmd)
	not freeze_exception_valid
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

# Structured tool calls for change actions during a freeze are denied.
allow = false if {
	input.context.freeze_window_active == true
	input.tool.arguments.action in change_actions
	not freeze_exception_valid
}

# Terraform apply/destroy during freeze is denied.
allow = false if {
	input.context.freeze_window_active == true
	input.tool.name == "terraform"
	input.tool.arguments.command in {"apply", "destroy"}
	not freeze_exception_valid
}

# Helm install/upgrade during freeze is denied.
allow = false if {
	input.context.freeze_window_active == true
	input.tool.name == "helm"
	input.tool.arguments.action in {"install", "upgrade", "rollback"}
	not freeze_exception_valid
}

# A freeze exception is valid only if it has been approved AND has not expired.
freeze_exception_valid if {
	input.context.freeze_exception == true
	input.context.freeze_exception_approver != ""
	input.context.freeze_exception_expires_at != ""
	time.parse_rfc3339_ns(input.context.freeze_exception_expires_at) > time.now_ns()
}

deny_reason = "Change freeze is active — deploy and config changes are blocked. Request a time-bound exception from your change advisory board." if {
	not allow
}
