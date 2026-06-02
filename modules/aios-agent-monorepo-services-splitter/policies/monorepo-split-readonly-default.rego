package policy

import rego.v1

# Intervention policy: PR-only delivery — block direct pushes to default branch and force-push.
default approval_required := false

approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	git_push_to_default_branch(cmd)
}

approval_required if {
	endswith(input.tool.name, "_execute_series")
	cmd := lower(input.tool.arguments.command)
	git_push_to_default_branch(cmd)
}

# Best-effort block for common default branch names; not exhaustive for every repo naming scheme.
git_push_to_default_branch(cmd) if {
	contains(cmd, "git push")
	regex.match(`origin (main|master|develop)`, cmd)
}

git_push_to_default_branch(cmd) if {
	contains(cmd, "push --force")
}

git_push_to_default_branch(cmd) if {
	contains(cmd, "push -f")
}
