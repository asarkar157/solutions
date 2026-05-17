package policy

default approval_required := false

# Prevent compliance agents from accessing actual PII/PHI data
approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	pii_access_pattern(cmd)
}

pii_access_pattern(cmd) if {
	contains(cmd, "select * from users")
}

pii_access_pattern(cmd) if {
	contains(cmd, "select * from patients")
}

pii_access_pattern(cmd) if {
	contains(cmd, "select * from customers")
}

pii_access_pattern(cmd) if contains(cmd, "pg_dump")

pii_access_pattern(cmd) if contains(cmd, "mysqldump")

pii_access_pattern(cmd) if contains(cmd, "mongodump")

approval_reason := "Accessing potential PII/PHI data requires human approval" if {
	approval_required
}
