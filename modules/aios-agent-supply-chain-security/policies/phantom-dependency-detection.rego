package policy

# Flag dependencies declared in package.json but never imported in code.

default approval_required := false

approval_required if {
	count(input.context.manifest_analysis.phantom_dependencies) > 0
}

approval_required if {
	some dep in input.context.manifest_analysis.declared_dependencies
	known_malicious(dep)
}

known_malicious(dep) if contains(dep, "plain-crypto")
known_malicious(dep) if contains(dep, "flatmap-stream")

approval_reason := "Phantom dependencies detected — declared but never imported in code" if {
	approval_required
}
