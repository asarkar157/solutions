Apply only operator-approved, reversible remediation, then report back.

## Steps

1. Confirm explicit operator approval exists for a specific action. If not, comment that remediation is pending approval and stop.
2. Allowed with approval: restart/recover Jenkins controller/service, rerun a Jenkins job or parent pipeline, propose a GitHub change/rollback, or make a narrow, reversible, named-target AWS change.
3. Never: recreate Jenkins via Terraform, delete Jenkins job history, delete Linear tickets, force-push/rewrite Git history, broad AWS/IAM changes, repository deletion, destructive deployment changes, or edits that hide the incident.
4. Comment back with: action taken, approval source, verification performed, result, and remaining risk/follow-up.

## Output schema

Emit `remediation_status` (not_attempted | attempted_with_approval | blocked_waiting_for_approval) and `remediation_result` when attempted.
