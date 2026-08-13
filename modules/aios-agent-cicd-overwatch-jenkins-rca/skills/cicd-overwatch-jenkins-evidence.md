---
name: cicd-overwatch-jenkins-evidence
description: Collect live Jenkins (and optional AWS/GitHub) evidence for a CICD Overwatch incident.
---

# CICD Overwatch live evidence collection

Use during `collect-live-evidence`. Load the `jenkins-topology` document from the `cicd-overwatch-jenkins-rca` knowledge base for the controller URL, job list, and per-job purpose.

1. Start from the job and build number named in the ticket context, if known. Otherwise, search Jenkins for recent failed builds of the release pipeline (`00-release-pipeline` and its child jobs `01`–`06`) and correlate by time and ticket text.
2. If the parent pipeline failed, inspect the child job matching the failed stage for exact console output.
3. Record both parent and child build numbers when both exist.
4. Pull from console logs: Git repository URL, ref, commit, release version, image URI, image digest, contract versions, and explicit failure messages.
5. If the public Jenkins endpoint itself is unreachable or returns 502, note that a public 502 can indicate controller/upstream availability rather than an authentication problem — check controller/service health (via AWS or remote-runner access, if attached) before concluding it's a permissions issue.
6. When AWS or GitHub integrations are attached, follow `cicd-overwatch-diagnose-recommend` guidance to pull the matching artifact/source evidence in the same pass.
7. Emit an `evidence_bundle` with every identifier and log excerpt collected, tagged by which job/system produced it.
