Collect live Jenkins evidence (and AWS/GitHub evidence when those integrations are attached) for the incident.

## Prerequisites

- `ticket_context` from the read-ticket-context stage.
- Jenkins integration (required).
- AWS and/or GitHub integrations (optional — extend evidence into artifacts and source).

## Steps

1. Start from the job/build named in `ticket_context`, or search Jenkins for recent failed release-pipeline builds correlated by time and ticket text.
2. Inspect the parent pipeline for stage-level timeline; inspect the failed child job for exact console output.
3. Record parent and child build numbers.
4. Extract Git repository URL, ref, commit, release version, image URI/digest, contract versions, and failure messages from console logs.
5. If the public Jenkins endpoint is unreachable or returns 502, treat that as possible controller/upstream unavailability rather than an auth failure, and check controller/service health if AWS or remote-runner access is available.
6. When available, pull matching AWS artifact/deployment evidence and GitHub source evidence at the exact commit Jenkins used.

## Output schema

Emit `evidence_bundle` with identifiers, log excerpts, and their source system, tagged per job.
