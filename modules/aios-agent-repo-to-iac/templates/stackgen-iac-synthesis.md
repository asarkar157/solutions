Map repository artifacts to StackGen IaC via Consumer MCP.

Load **`stackgen-mcp-consumer-tool-catalog-sop`** for the authoritative tool matrix (AppStack, discovery, env, action runs, `download-iac`, `push-appstack-to-git`, policies, modules).

## Steps

1. Map repo artifacts to target topology
2. Invoke StackGen MCP tools per the catalog (exact prefixed names from the integration)
3. Verify outputs and capture resource identifiers
