package policy

import rego.v1

# Intervention policy for db-state-split-architect: do not add HITL escalation from this policy.
# Auto-approval for Consumer MCP tools is enforced on the agent via `sg_agent.auto_approve_tools`
# (`tool = "<stackgen_mcp_integration_name>_*"`, e.g. stackgen-mcp_*).

default approval_required := false
