package policy

default allow := true

# Nanoseconds since epoch for input.timestamp (RFC3339). Undefined when missing/invalid.
factsheet_ts_ns := time.parse_rfc3339_ns(ts) if {
	ts := object.get(input, "timestamp", "")
	ts != ""
}

# Signed age: policy evaluation clock minus factsheet instant (negative if timestamp is in the future).
factsheet_age_ns := time.now_ns() - ns if {
	ns := factsheet_ts_ns
}

thirty_min_ns := 30 * 60 * 1000000000
five_min_ns := 5 * 60 * 1000000000

# Sensitive shell access when factsheet timestamp is stale vs. policy evaluation clock (replay guard).
stale_sensitive_blocked if {
	factsheet_age_ns > thirty_min_ns
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	data_access_shell(cmd)
}

allow := false if {
	stale_sensitive_blocked
}

# Large clock skew ahead — likely bad client clock or tampered input.timestamp.
skew_sensitive_blocked if {
	factsheet_age_ns < (0 - five_min_ns)
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	data_access_shell(cmd)
}

allow := false if {
	skew_sensitive_blocked
}

# Shell commands that export or query sensitive data without redaction are denied.
allow := false if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	data_access_shell(cmd)
	not redaction_in_cmd(cmd)
	not stale_sensitive_blocked
	not skew_sensitive_blocked
}

data_access_shell(cmd) if {
	contains(cmd, "psql")
	contains(cmd, "copy")
}

data_access_shell(cmd) if {
	contains(cmd, "mysqldump")
}

data_access_shell(cmd) if {
	contains(cmd, "mysql")
	contains(cmd, "select")
	not contains(cmd, "mysqldump")
}

data_access_shell(cmd) if {
	contains(cmd, "pg_dump")
}

data_access_shell(cmd) if {
	contains(cmd, "mongodump")
}

data_access_shell(cmd) if {
	contains(cmd, "aws s3 cp")
	pii_bucket_pattern(cmd)
}

data_access_shell(cmd) if {
	contains(cmd, "aws s3 sync")
	pii_bucket_pattern(cmd)
}

data_access_shell(cmd) if {
	contains(cmd, "bq extract")
}

# Known PII-related bucket/path patterns.
pii_bucket_pattern(cmd) if contains(cmd, "pii")
pii_bucket_pattern(cmd) if contains(cmd, "user-data")
pii_bucket_pattern(cmd) if contains(cmd, "customer-data")
pii_bucket_pattern(cmd) if contains(cmd, "healthcare")
pii_bucket_pattern(cmd) if contains(cmd, "payment")

# Redaction pipeline indicators in the command.
redaction_in_cmd(cmd) if contains(cmd, "--redact")
redaction_in_cmd(cmd) if contains(cmd, "| redact")
redaction_in_cmd(cmd) if contains(cmd, "redaction")

deny_reason := "Data risk: input.timestamp is more than 30 minutes behind server evaluation time; retry to prevent replayed sensitive access." if {
	not allow
	stale_sensitive_blocked
}

deny_reason := "Data risk: input.timestamp is more than 5 minutes ahead of server clock; fix client time or retry." if {
	not allow
	skew_sensitive_blocked
}

deny_reason := "Data risk: target contains sensitive data (PII/PCI/PHI). Enable the redaction pipeline before exporting or querying." if {
	not allow
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	data_access_shell(cmd)
	not redaction_in_cmd(cmd)
	not stale_sensitive_blocked
	not skew_sensitive_blocked
}
