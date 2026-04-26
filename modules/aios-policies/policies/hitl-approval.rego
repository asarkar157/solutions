package policy

import future.keywords.in

# By default, deny the approval
default allow := false

# Example 1: Allow any approval if the approver has the "admin" role (requires passing user info into the evaluation context)
allow if {
	input.approver.role == "admin"
}

# Example 2: Allow specific users to approve specific tools for specific agents
# Here we define a static ABAC mapping for demonstration purposes.
# In a real-world scenario, you might inject this data via OPA's data documents or
# lookup from an external identity provider.
agent_approvals := {
	"infrastructure-agent": {
		"alice@company.com": ["create_bucket", "delete_bucket", "*"],
		"bob@company.com": ["create_bucket"],
	},
	"locked-down-agent": {"alice@company.com": ["*"]},
}

allow if {
	# Check if the tool is in the list of allowed tools for this agent and approver
	allowed_tools := agent_approvals[input.agent.name][input.approver.email]

	# Allow if they have wildcard access or specific tool access
	"*" in allowed_tools
}

allow if {
	# Check if the tool is in the list of allowed tools for this agent and approver
	allowed_tools := agent_approvals[input.agent.name][input.approver.email]

	input.tool.name in allowed_tools
}

# Output reason if rejected
approval_reason := "Approver is not authorized to approve this tool for this agent." if {
	not allow
}
