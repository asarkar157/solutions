package policy

default approval_required := false

rollout_actions := {"rollout_proceed", "canary_promote", "traffic_shift_expand", "scale_up_global"}

# Shell commands that promote or expand a rollout require post-action verification.
approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	rollout_shell_pattern(cmd)
	not post_action_checks_passed
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

# Structured tool calls for broader rollout require post-action checks.
approval_required if {
	input.tool.arguments.action in rollout_actions
	not post_action_checks_passed
}

# Helm upgrade in production after initial canary requires verification.
approval_required if {
	input.tool.name == "helm"
	input.tool.arguments.action in {"upgrade", "rollback"}
	input.tool.arguments.namespace in {"production", "prod"}
	not post_action_checks_passed
}

# Post-action checks pass when the context graph confirms SLI health.
# When the context graph is not integrated, this rule is undefined,
# meaning post_action_checks_passed is false and approval IS required.
# This is intentional: fail closed for rollout expansion.
post_action_checks_passed if {
	input.context.sli_status == "healthy"
	input.context.new_alerts_count == 0
	input.context.observation_minutes >= 10
}

approval_reason := "Post-action verification required: SLI must be healthy with zero new alerts for ≥ 10 minutes before proceeding to broader rollout" if {
	approval_required
}
