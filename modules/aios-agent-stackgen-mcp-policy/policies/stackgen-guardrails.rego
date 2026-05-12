package policy

import rego.v1

# Fail-closed for MCP tools typed as integration_type == "mcp": only allow-listed read-style
# tool names pass. Other tool invocations (non-MCP) are allowed so this policy can attach
# without blocking unrelated integrations.
#
# Guild often prefixes MCP tools with the integration name (e.g. stackgen-mothership-mcp_get_appstacks);
# we allow short names (docs examples) and suffix matches for real Consumer/Mothership tools.

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

# Suffixes after integration prefix (stackgen-mcp_*, stackgen-mothership-mcp_*, etc.)
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
	"_get_module_versions",
	"_module_usage_in_appstacks",
	"_get_policies",
	"_get_scan_results",
	"_list_cloud_discoveries",
	"_get_resources_from_discovery",
	"_list-git-configuration",
	"_list-available-secrets",
	"_get_stackgen_projects",
	"_get_appstack_tf_variables",
	"_get_appstack_tf_locals",
	"_get_appstack_tf_outputs",
	"_get_appstack_tf_providers",
	"_get_stackgen_policy_schema",
	"download-iac",
	"detect-drift",
}

deny_reason := sprintf(
	"StackGen MCP guardrail: tool '%s' is not an allow-listed read operation.",
	[input.tool.name],
) if {
	not allow
}
