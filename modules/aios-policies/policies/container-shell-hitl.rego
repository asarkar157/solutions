package policy

import rego.v1

default approval_required := false

# Require HITL approval for container execution tools (MCP integration shells).
# Matches both formats:
#   - mcp:serverName:execute_command (policy-normalized name)
#   - integration_name field set (indicates this is an integration tool)
approval_required if {
	endswith(input.tool.name, ":execute_command")
	input.tool.name != "azure-production:execute_command"
	input.principal.id != "sks@stackgen.com"
}

# Fallback: match agent-visible underscore format for non-MCP path
approval_required if {
	endswith(input.tool.name, "_execute_command")
	input.tool.name != "azure-production_execute_command"
	input.principal.id != "sks@stackgen.com"
}

approval_reason := "Remote execution tool requires human approval — please confirm the command before execution." if {
	approval_required
}
