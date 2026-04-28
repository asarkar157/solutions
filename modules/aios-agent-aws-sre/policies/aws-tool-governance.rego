package policy

import rego.v1

default allow := false

default approval_required := false

# Allow read-only AWS CLI commands and basic Kubernetes diagnostics
allow if {
	input.tool.name == "aws_execute_command"
	cmd := input.tool.arguments.command
	is_read_only(cmd)
}

# Allow _execute_parallel when ALL commands are read-only
allow if {
	endswith(input.tool.name, "_execute_parallel")
	commands := input.tool.arguments.commands
	count(commands) > 0
	every c in commands {
		is_read_only(c.command)
	}
}

allow if {
	input.tool.name == "kubectl_execute_command"
	cmd := input.tool.arguments.command
	is_read_only(cmd)
}

is_shell_tool if {
	endswith(input.tool.name, "_execute_parallel")
}

# Require intervention for destructive single commands
approval_required if {
	input.tool.name == "aws_execute_command"
	cmd := input.tool.arguments.command
	not is_read_only(cmd)
}

approval_required if {
	input.tool.name == "kubectl_execute_command"
	cmd := input.tool.arguments.command
	not is_read_only(cmd)
}

# Require intervention for parallel commands when any command is destructive
approval_required if {
	endswith(input.tool.name, "_execute_parallel")
	commands := input.tool.arguments.commands
	some c in commands
	not is_read_only(c.command)
}

approval_reason := sprintf("Destructive command requires approval: '%s'", [input.tool.arguments.command]) if {
	endswith(input.tool.name, "_execute_command")
	approval_required
}

approval_reason := sprintf("Parallel batch contains destructive command(s) requiring approval") if {
	endswith(input.tool.name, "_execute_parallel")
	approval_required
}

# Helper to define read-only commands
is_read_only(cmd) if {
	read_only_verbs := ["get", "describe", "list", "logs", "top", "version", "status", "events"]
	verb := split(cmd, " ")[1] # Usually aws <service> <verb> or kubectl <verb>
	verb == read_only_verbs[_]
}

is_read_only(cmd) if {
	startswith(cmd, "kubectl get")
}

is_read_only(cmd) if {
	startswith(cmd, "kubectl describe")
}

is_read_only(cmd) if {
	startswith(cmd, "kubectl logs")
}

is_read_only(cmd) if {
	startswith(cmd, "aws ec2 describe-")
}

is_read_only(cmd) if {
	startswith(cmd, "aws s3 ls")
}

is_read_only(cmd) if {
	startswith(cmd, "aws iam list-")
}

is_read_only(cmd) if {
	startswith(cmd, "aws iam get-")
}

is_read_only(cmd) if {
	startswith(cmd, "aws eks describe-")
}
