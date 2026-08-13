---
name: cicd-overwatch-ticket-claim
description: Claim an inbound Linear ticket and move it to in-progress before investigating.
---

# CICD Overwatch ticket claim

Use at the start of the `claim-ticket-in-progress` stage.

1. Confirm the ticket is a CICD Overwatch / Jenkins-related incident (title, description, or labels reference Jenkins, a build, a pipeline, or a release failure).
2. Assign the ticket to yourself (or the configured bot identity) via the Linear integration if assignment is supported and unset.
3. Move the ticket state to "In Progress" (or the workspace's equivalent active state).
4. Post a short acknowledgement comment: you are investigating, and you will follow up with an RCA.
5. Do not diagnose anything yet — this stage only claims ownership so humans know the ticket is being worked.
