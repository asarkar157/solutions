package policy

# Block npm installs when packages lack OIDC/SLSA provenance attestation.

default approval_required = false

approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	npm_install_command(cmd)
	some _, status in input.context.provenance
	not status.verified
}

npm_install_command(cmd) if contains(cmd, "npm install")
npm_install_command(cmd) if contains(cmd, "npm ci")
npm_install_command(cmd) if contains(cmd, "npm add")

approval_reason = "Packages missing OIDC/SLSA provenance require review before install" if {
	approval_required
}
