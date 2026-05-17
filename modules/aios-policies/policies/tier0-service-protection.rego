package policy

default allow := true

# Deny shell commands targeting known tier-0 services with unsafe operations.
allow := false if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	tier0_unsafe_shell(cmd)
}

tier0_unsafe_shell(cmd) if {
	contains(cmd, "kubectl")
	contains(cmd, "delete")
	tier0_service_in_cmd(cmd)
}

tier0_unsafe_shell(cmd) if {
	contains(cmd, "kubectl")
	contains(cmd, "scale")
	tier0_service_in_cmd(cmd)
}

tier0_unsafe_shell(cmd) if {
	contains(cmd, "helm uninstall")
	tier0_service_in_cmd(cmd)
}

tier0_unsafe_shell(cmd) if {
	contains(cmd, "helm delete")
	tier0_service_in_cmd(cmd)
}

# Match known tier-0 service names in shell commands.
# Update this list with your actual tier-0 service names.
tier0_service_in_cmd(cmd) if contains(cmd, "payments")
tier0_service_in_cmd(cmd) if contains(cmd, "auth-service")
tier0_service_in_cmd(cmd) if contains(cmd, "api-gateway")
tier0_service_in_cmd(cmd) if contains(cmd, "core-database")

deny_reason := "Tier-0 service protection: only safe actions (read-only, diagnostics, canary restart) are allowed without approval" if {
	not allow
}
