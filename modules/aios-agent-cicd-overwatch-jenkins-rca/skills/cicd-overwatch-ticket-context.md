---
name: cicd-overwatch-ticket-context
description: Extract concrete, reproducible identifiers from a Linear ticket before touching Jenkins.
---

# CICD Overwatch ticket context

Use during `read-ticket-context`. Load the `incident-investigation-sop` document from the `cicd-overwatch-jenkins-rca` knowledge base for the full intake checklist.

1. Read the ticket title, description, all comments, labels, assignee, and any linked URLs.
2. Extract concrete identifiers where present: Jenkins job name, build number, Jenkins URL, Git repository URL, Git ref, Git commit, image URI or digest, environment, and any observed HTTP status.
3. Treat labels like `incident` or `help-needed` as routing signals only — they do not indicate root cause.
4. If identifiers are missing or ambiguous, record what you will search for (e.g. "most recent failed build of 00-release-pipeline around the ticket's created time") — do not guess a build number.
5. Emit a short `ticket_context` summary (identifiers found, identifiers still needed) for the next stage to consume.
