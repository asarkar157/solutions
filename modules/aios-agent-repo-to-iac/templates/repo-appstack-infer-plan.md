After GitHub discovery: infer StackGen surface area. Use **`stackgen-mcp-consumer-tool-catalog-sop`** for the StackGen **user** MCP matrix (`search_tools` if your org adds tools).

## Steps

1. `stackgen-mcp_me` — confirm project scope; note `project_name` UUID for subsequent calls
2. `stackgen-mcp_get_supported_resource_types` — choose resource types and resource packs (UUIDs only for packs)
3. `stackgen-mcp_get_appstacks` with labels `["template"]` — optional template `appstack_ref_id` for `stackgen-mcp_create_appstack`
4. Map repo artifacts (Dockerfile, Kubernetes, Terraform, etc.) to identifiers and `resource_type` strings; list connection candidates for `stackgen-mcp_get_possible_resource_connections` later
