package policy

default approval_required = false

# Gate destructive shell patterns: rm -rf, force-delete, terraform destroy, etc.
# Read-only shell commands are allowed through without HITL.
approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	destructive_pattern(cmd)
}

destructive_pattern(cmd) if contains(cmd, "rm -rf")
destructive_pattern(cmd) if contains(cmd, "force-delete")
destructive_pattern(cmd) if contains(cmd, "terraform destroy")
destructive_pattern(cmd) if contains(cmd, "tofu destroy")
destructive_pattern(cmd) if contains(cmd, "kubectl delete")
destructive_pattern(cmd) if contains(cmd, "helm uninstall")
destructive_pattern(cmd) if contains(cmd, "helm delete")
destructive_pattern(cmd) if contains(cmd, "aws iam delete")
destructive_pattern(cmd) if contains(cmd, "aws ec2 terminate")
destructive_pattern(cmd) if contains(cmd, "drop table")
destructive_pattern(cmd) if contains(cmd, "drop database")
destructive_pattern(cmd) if contains(cmd, "truncate ")
destructive_pattern(cmd) if contains(cmd, "mkfs")
destructive_pattern(cmd) if contains(cmd, "dd if=")

approval_reason = "Destructive operation requires human approval" if {
	approval_required
}
