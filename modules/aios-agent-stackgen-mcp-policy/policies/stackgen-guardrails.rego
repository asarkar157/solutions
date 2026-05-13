package policy

import rego.v1

# Fail-closed for MCP tools typed as integration_type == "mcp": only allow-listed read-style
# tool names pass. Other tool invocations (non-MCP) are allowed so this policy can attach
# without blocking unrelated integrations.
#
# Guild often prefixes MCP tools with the integration name (e.g. stackgen-mcp_get_appstacks);
# we allow short names (optional graph-style tools) and suffix matches aligned with StackGen user MCP reads.

default allow := false

allow if {
	not input.tool.integration_type == "mcp"
}

allow if {
	input.tool.integration_type == "mcp"
	read_only_stackgen_tool(input.tool.name)
}

read_only_stackgen_tool(name) if {
	name in allowed_short_names
}

read_only_stackgen_tool(name) if {
	endswith(name, "mcp_me")
}

read_only_stackgen_tool(name) if {
	some sfx in allowed_name_suffixes
	endswith(name, sfx)
}

allowed_short_names := {
	"get_application_graph",
	"list_resources",
	"describe_infrastructure",
	"explore_api_docs",
	"get_operation_schema",
}

# Suffixes after integration prefix (stackgen-mcp_*, stackgen-mothership-mcp_*, etc.).
# Read-only allow list for integration_type == "mcp". Includes StackGen **user / AppStack**
# MCP (`…/api/mcp/user`) get_* tools; other products may expose extra tools — extend here if policy should allow them.
allowed_name_suffixes := {
	"_get_appstacks",
	"_get_application_graph",
	"_list_resources",
	"_describe_infrastructure",
	"_explore_api_docs",
	"_get_operation_schema",
	"_get_appstack_resources",
	"_get_supported_resource_types",
	"_get_resource_configurations",
	"_get_resource_type_configurations",
	"_get_possible_resource_connections",
	"_get_env_profiles",
	"_get_snapshots",
	"_get_current_violations",
	"_get_action_run",
	"_get_action_run_logs",
	"_get_appstack_tf_variables",
	"_get_appstack_tf_locals",
	"_get_appstack_tf_outputs",
	"_get_appstack_tf_providers",
}

deny_reason := sprintf(
	"StackGen MCP guardrail: tool '%s' is not an allow-listed read operation.",
	[input.tool.name],
) if {
	not allow
}
