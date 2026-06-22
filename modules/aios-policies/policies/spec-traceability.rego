package policy

import rego.v1

default approval_required := false

is_runner_shell if {
	endswith(input.tool.name, "_execute_series")
}

is_runner_shell if {
	endswith(input.tool.name, "_execute_command")
}

cmd := lower(input.tool.arguments.command)

# Ad-hoc PR creation must cite a spec or OpenSpec change path in the command/body.
approval_required if {
	is_runner_shell
	contains(cmd, "gh pr create")
	not contains(cmd, "specs/")
	not contains(cmd, "openspec/changes/")
}

# Raw commit+push without spec linkage markers in the same command batch.
approval_required if {
	is_runner_shell
	contains(cmd, "git commit")
	contains(cmd, "git push")
	not contains(cmd, "specs/")
	not contains(cmd, "openspec/")
}

approval_reason := "Spec traceability: use stage-runner.sh commit-pr after validate, or include specs/ or openspec/changes/ in PR/commit context." if {
	approval_required
}
