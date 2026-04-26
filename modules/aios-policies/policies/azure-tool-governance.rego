package policy

import rego.v1

default allow := false

default approval_required := false

# ---- Non-shell tools are always allowed ----
is_shell_tool if {
	endswith(input.tool.name, "_execute_command")
}

is_shell_tool if endswith(input.tool.name, ":execute_command")
is_shell_tool if input.tool.name == "run_shell"

allow if not is_shell_tool

# ---- Shell tools: allow read-only commands ----
allow if {
	is_shell_tool
	cmd := input.tool.arguments.command
	startswith(cmd, "az ")
	az_read_only(cmd)
}

allow if {
	is_shell_tool
	cmd := input.tool.arguments.command
	kubectl_read_only(cmd)
}

allow if {
	is_shell_tool
	cmd := input.tool.arguments.command
	contains(cmd, "clickhouse-client")
	contains(cmd, "SELECT")
	not contains(cmd, "DROP")
	not contains(cmd, "ALTER")
	not contains(cmd, "TRUNCATE")
	not contains(cmd, "INSERT")
}

# Read-only Azure CLI: list, show, get, peek
az_read_only(cmd) if {
	contains(cmd, " list")
	not destructive(cmd)
}

az_read_only(cmd) if {
	contains(cmd, " show")
	not destructive(cmd)
}

az_read_only(cmd) if {
	contains(cmd, " get-credentials")
}

az_read_only(cmd) if {
	contains(cmd, " login")
}

az_read_only(cmd) if {
	contains(cmd, "peek-messages")
}

az_read_only(cmd) if {
	contains(cmd, " describe")
}

# Read-only kubectl
kubectl_read_only(cmd) if {
	startswith(cmd, "kubectl get")
}

kubectl_read_only(cmd) if {
	startswith(cmd, "kubectl describe")
}

kubectl_read_only(cmd) if {
	startswith(cmd, "kubectl logs")
}

kubectl_read_only(cmd) if {
	startswith(cmd, "kubectl get events")
}

# ---- Destructive operations require HITL approval ----
approval_required if {
	is_shell_tool
	cmd := input.tool.arguments.command
	destructive(cmd)
}

approval_reason := sprintf("Destructive command requires SRE approval: '%s'", [input.tool.arguments.command]) if {
	approval_required
}

# Destructive command patterns
destructive(cmd) if contains(cmd, "delete")
destructive(cmd) if contains(cmd, "purge")
destructive(cmd) if contains(cmd, "stop")
destructive(cmd) if contains(cmd, "restart")
destructive(cmd) if contains(cmd, "DROP")
destructive(cmd) if contains(cmd, "TRUNCATE")
destructive(cmd) if contains(cmd, "rm -rf")

# Only produce a denial reason for shell tools that are not allowed
reason := msg if {
	is_shell_tool
	not allow
	not approval_required
	msg := sprintf("Policy azure-tool-governance: command not in allowlist. Only read-only Azure CLI, kubectl, and Clickhouse SELECT queries are permitted. Got: '%s'", [input.tool.arguments.command])
}
