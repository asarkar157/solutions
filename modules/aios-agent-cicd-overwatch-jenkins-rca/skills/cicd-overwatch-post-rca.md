---
name: cicd-overwatch-post-rca
description: Post a concise, structured RCA comment back to the Linear ticket.
---

# CICD Overwatch post RCA to Linear

Use during `post-linear-rca`.

Post one Linear comment containing exactly:

- **Diagnosis summary** — one or two sentences.
- **Evidence reviewed** — jobs/builds/commits/AWS resources checked, with identifiers.
- **Probable root cause** — the failure class and the specific cause within it.
- **Recommended fix** — the smallest safe change, named explicitly.
- **Remediation status** — one of: not attempted, attempted with approval, or blocked waiting for approval.
- **Verification steps and current result** — what was or will be checked, and the outcome so far.

Keep the comment concise and scannable — this is a status update for humans, not the full evidence dump. Do not include remediation actions here; that only happens (with approval) in the next stage.
