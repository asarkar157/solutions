End-to-end Jenkins CI/CD incident investigation triggered by an inbound Linear ticket: claim → read context → collect live Jenkins (and optional AWS/GitHub) evidence → diagnose and recommend → post RCA to Linear → optional operator-approved remediation.

## Trigger

- **Active**: Linear webhook (`sg_webhook` `cicd-overwatch-linear-ticket-receiver`) POST to StackGen when `enable_linear_webhook = true`.
- **Passive**: Queries mentioning a Linear ticket with a Jenkins/CI/CD failure.

## Stages

1. **claim-ticket-in-progress** — Assign and move the Linear ticket to in-progress; acknowledge investigation has started.
2. **read-ticket-context** — Parse the ticket and extract concrete identifiers (job, build, commit, image, environment).
3. **collect-live-evidence** — Query Jenkins (and AWS/GitHub when attached) for build metadata, console output, and artifact/source evidence.
4. **diagnose-and-recommend** — Classify the failure class, rule out an alternative, recommend the smallest safe fix and verification steps.
5. **post-linear-rca** — Post a concise RCA comment to the Linear ticket.
6. **optional-approved-remediation** — Only with explicit operator approval: execute the fix, then report action, verification, and result back to Linear.
