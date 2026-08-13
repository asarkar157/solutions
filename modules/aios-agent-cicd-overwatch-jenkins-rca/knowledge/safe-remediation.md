# CICD Overwatch Safe Remediation

Remediation is optional and must be approval-gated.

## Allowed With Explicit Approval

- Restart or recover the Jenkins controller/service when evidence shows controller unavailability.
- Rerun a Jenkins job or parent pipeline when the underlying cause has been fixed or the failure is transient.
- Comment on the Linear ticket with RCA, recommended action, and verification status.
- Propose a GitHub change or rollback when source evidence identifies a bad change.
- Inspect AWS resources and make narrow, reversible changes when the approved action names the target and expected effect.

## Not Allowed Without Separate Approval

- Recreating the Jenkins instance with Terraform.
- Deleting Jenkins job history.
- Deleting Linear tickets.
- Force-pushing or rewriting Git history.
- Broad AWS cleanup, IAM changes, repository deletion, or destructive deployment changes.
- Changing demo automation files to hide or suppress the incident.

## Remediation Comment

After an approved action, comment back in Linear with:

- Action taken.
- Approval source.
- Verification command or system checked.
- Result.
- Remaining risk or follow-up work.
