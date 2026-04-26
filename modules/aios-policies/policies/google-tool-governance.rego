package policy

import rego.v1

default allow := false

default approval_required := false

# Allow all google integration tools. The prompt indicates all read operations are always allowed.
allow if {
	contains(input.tool.name, "google")
}

# Allow non-shell tools like typical MCP read actions
allow if {
	not is_shell_tool
}

is_shell_tool if {
	endswith(input.tool.name, "_execute_command")
}

is_shell_tool if {
	endswith(input.tool.name, ":execute_command")
}

# Require HITL approval for mutating Google tools
approval_required if {
	is_mutating_tool
}

approval_reason := sprintf("Google Workspace mutating action requires approval: '%s'", [input.tool.name]) if {
	approval_required
}

is_google_tool if {
	contains(input.tool.name, "google")
}

is_mutating_tool if {
	is_google_tool
	not is_read_only_tool
}

is_read_only_tool if {
	p := [":get_", "_get_", ":list_", "_list_", ":search_", "_search_", ":check_", "_check_", ":read_", "_read_", ":debug_", "_debug_", ":inspect_", "_inspect_", ":download_", "_download_"][_]
	contains(input.tool.name, p)
}
