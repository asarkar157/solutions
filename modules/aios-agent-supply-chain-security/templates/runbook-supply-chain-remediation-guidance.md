Propose remediation after evidence from prior stages has passed the quality gate.

## Steps

1. Confirm the correlation summary lists concrete packages/repos and cites the three evidence types (audit/provenance, sandbox, graph delta).
2. For each item, choose one path: pin/remove dependency, upgrade to a verified version, add CI provenance checks, or isolate (quarantine) phantom imports.
3. Reference org policies: unverified installs, sandbox egress, phantom dependencies; prefer smallest blast radius.
4. **Output:** ordered remediation steps, owner hints (repo / team), and follow-up validation (re-run audit, CI job).
