package policy

import rego.v1

default allow := true

# ─── Read-only guard: the Langfuse observer agent is restricted to
# read-only / analytics tools. Any tool that could mutate traces,
# scores, or projects requires HITL approval.
#
# Safe (allowed through): get_*, list_*, search_*, fetch_*
# Blocked: delete_*, create_*, update_*, archive_*, annotate_*,
#          bulk_*, execute_command (shell)

# Block mutations via the langfuse MCP server tools.
allow := false if {
	langfuse_tool(input.tool.name)
	mutating_tool(input.tool.name)
}

# Block shell exec on the langfuse integration container.
allow := false if {
	contains(input.tool.name, "langfuse")
	endswith(input.tool.name, "_execute_command")
}

allow := false if {
	contains(input.tool.name, "langfuse")
	endswith(input.tool.name, ":execute_command")
}

# ─── helpers ──────────────────────────────────────────────────────

langfuse_tool(name) if contains(name, "langfuse")

mutating_tool(name) if contains(name, "delete_")
mutating_tool(name) if contains(name, "create_")
mutating_tool(name) if contains(name, "update_")
mutating_tool(name) if contains(name, "archive_")
mutating_tool(name) if contains(name, "annotate_")
mutating_tool(name) if contains(name, "bulk_")

deny_reason := "Langfuse observer is read-only. Mutating operations (create, update, delete, archive) are blocked." if {
	not allow
}
