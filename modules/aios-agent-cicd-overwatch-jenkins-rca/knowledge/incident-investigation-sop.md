# CICD Overwatch Incident Investigation SOP

Use this SOP when a Linear ticket reports a CI/CD failure involving the CICD Overwatch Jenkins demo.

## Guardrails

- Do not treat ticket labels as the root cause. `incident` and `help-needed` only mean the issue needs investigation.
- Do not use demo automation history files as diagnostic evidence, including `.demo-breakage/incident-events.jsonl`, `.demo-pulse/pulse-events.jsonl`, or `.demo-reset/reset-events.jsonl`.
- Prefer live system evidence: Linear ticket text and comments, Jenkins build metadata and console output, GitHub repository state, AWS resource state, and public application health.
- Keep the investigation reproducible by recording exact job names, build numbers, URLs, Git refs, commits, image identifiers, and timestamps.
- Do not apply remediation until an operator explicitly approves it.

## Intake

1. Read the Linear ticket title, description, comments, labels, assignee, and linked URLs.
2. Extract concrete identifiers: Jenkins job, build number, Jenkins URL, Git repository URL, Git ref, Git commit, image URI or digest, environment, and observed HTTP status.
3. If identifiers are missing, search Jenkins for recent failed CICD Overwatch builds and correlate by time and ticket text.

## Evidence Collection

Collect enough evidence to support or reject each plausible class:

- Jenkins controller or job health: public endpoint status, controller availability, queue/build state, plugin/runtime errors, child-job logs, and parent-pipeline stage status.
- Source-control or codebase issue: GitHub ref and commit used by Jenkins, changed files at that commit, repository docs, build/test output, and compatibility reports.
- Image/artifact/registry issue: Jenkins image build/push output, image URI/digest evidence, AWS artifact systems related to the release, and downstream deployment references.

## Diagnosis

Do not stop at the first symptom. Explain:

- What failed.
- Which system produced the primary error.
- What evidence links the symptom to the likely root cause.
- What alternative explanations were checked and why they are less likely.
- What remediation is safe, and whether approval is required.

## Linear Comment

Post a concise Linear comment with:

- Diagnosis summary.
- Evidence reviewed.
- Probable root cause.
- Recommended fix.
- Remediation status: not attempted, attempted with approval, or blocked waiting for approval.
- Verification steps and current result.
