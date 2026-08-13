Claim ownership of an inbound Linear ticket reporting a CICD Overwatch / Jenkins incident.

## Steps

1. Confirm the ticket concerns a Jenkins job, pipeline, or release failure.
2. Assign the ticket to the investigating agent identity if unassigned.
3. Move the ticket to an "In Progress" (or equivalent active) state.
4. Post a short acknowledgement comment noting investigation has started.

## Output schema

Emit `ticket_claimed=true` with the ticket ID and new state.
