Read the full Linear ticket and extract concrete, reproducible identifiers before touching Jenkins.

## Steps

1. Read title, description, comments, labels, assignee, and linked URLs.
2. Extract identifiers where present: Jenkins job, build number, Jenkins URL, Git repository URL, Git ref, Git commit, image URI/digest, environment, observed HTTP status.
3. Treat labels (`incident`, `help-needed`) as routing signals only, never as root cause.
4. If identifiers are missing, note what to search for in the next stage instead of guessing.

## Output schema

Emit `ticket_context` with `identifiers_found{}` and `identifiers_needed[]`.
