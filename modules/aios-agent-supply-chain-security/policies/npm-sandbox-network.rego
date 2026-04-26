package policy

# Block sandbox installs that access non-allowlisted domains.

default approval_required = false

allowlisted_domains := {
	"registry.npmjs.org",
	"github.com",
	"api.github.com",
	"objects.githubusercontent.com",
	"rekor.sigstore.dev",
}

approval_required if {
	input.context.sandbox == true
	some activity in input.context.network_activity
	not allowlisted(activity.domain)
}

allowlisted(domain) if {
	some d in allowlisted_domains
	domain == d
}

allowlisted(domain) if endswith(domain, ".npmjs.org")
allowlisted(domain) if endswith(domain, ".github.com")
allowlisted(domain) if endswith(domain, ".sigstore.dev")

approval_reason = "Sandbox detected network calls to non-allowlisted domains" if {
	approval_required
}
