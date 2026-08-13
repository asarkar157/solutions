---
name: cicd-overwatch-safe-remediation
description: Apply only operator-approved, reversible remediation and report back to Linear.
---

# CICD Overwatch safe remediation

Use during `optional-approved-remediation`. Load `safe-remediation` from the `cicd-overwatch-jenkins-rca` knowledge base for the full allow/deny list.

1. This stage is optional — only act if an operator has explicitly approved a specific action (in the ticket, a workflow input, or an operator message). If there is no explicit approval, comment that remediation is pending approval and stop; do not guess at intent.
2. Allowed with explicit approval: restart/recover the Jenkins controller or service, rerun a Jenkins job or parent pipeline, propose a GitHub change or rollback, or make a narrow, reversible, named-target AWS change.
3. Never do, even with a vague approval: recreate Jenkins via Terraform, delete Jenkins job history, delete Linear tickets, force-push or rewrite Git history, broad AWS cleanup/IAM changes, repository deletion, destructive deployment changes, or edit demo automation files to hide the incident.
4. After acting, comment on the Linear ticket with: action taken, approval source, verification command or system checked, result, and remaining risk or follow-up work.
5. If the approved action fails or the fix doesn't verify, report that honestly instead of marking the ticket resolved.
