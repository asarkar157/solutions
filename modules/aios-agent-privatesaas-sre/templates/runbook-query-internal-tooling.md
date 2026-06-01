Query internal operator tooling for ownership, dependencies, and blast radius.

## Steps

1. Resolve service name to catalog entry via internal REST API search.
2. Record owning team, on-call rotation hints, and dependency graph.
3. Fetch related runbook index entries when exposed by the API.
4. Emit `internal_tooling_context` JSON.

## Guardrails

- Read-only API calls.
- Redact secrets from responses.
