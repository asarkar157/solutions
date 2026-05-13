package policy

import rego.v1

# Intervention policy for db-state-split-architect: do not add HITL escalation from this policy.
# Auto-approval for Consumer MCP tools is enforced on the agent via `hitl.always_allowed`
# pattern `<stackgen_mcp_integration_name>_*` when that variable is set (e.g. stackgen-mcp_* → prefix stackgen-mcp_).

default approval_required := false
