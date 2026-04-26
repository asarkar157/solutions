package policy

default allow := true

sensitive_classifications := {"PII", "PCI", "PHI", "HIPAA", "GDPR"}

# Shell commands that export or query sensitive data without redaction are denied.
allow := false if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	data_access_shell(cmd)
	not redaction_in_cmd(cmd)
}

data_access_shell(cmd) if {
	contains(cmd, "psql")
	contains(cmd, "copy")
}

data_access_shell(cmd) if {
	contains(cmd, "mysqldump")
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

# Context-graph enhanced: deny log/data exports when the context graph
# classifies the target as containing sensitive data.
allow := false if {
	input.context.data_classification in sensitive_classifications
	input.tool.name in {"log_export", "log_download", "data_export", "database", "data_query"}
	not object.get(input.tool.arguments, "redaction_enabled", false)
}

# Context-graph enhanced: deny raw data queries against classified data stores.
allow := false if {
	input.context.data_classification in sensitive_classifications
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	any_db_client(cmd)
	not redaction_in_cmd(cmd)
}

any_db_client(cmd) if contains(cmd, "psql")
any_db_client(cmd) if contains(cmd, "mysql")
any_db_client(cmd) if contains(cmd, "mongo")
any_db_client(cmd) if contains(cmd, "redis-cli")
any_db_client(cmd) if contains(cmd, "bq query")

deny_reason := "Data risk: target contains sensitive data (PII/PCI/PHI). Enable the redaction pipeline before exporting or querying." if {
	not allow
}
