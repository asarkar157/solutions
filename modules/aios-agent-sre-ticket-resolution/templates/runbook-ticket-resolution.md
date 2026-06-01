Execute safe AWS remediation for a ServiceNow ticket, update ServiceNow, and notify Slack.

## Prerequisites

- `resolution_plan` JSON from propose-resolution.
- resolution-safety-gate passed (no blocked P1/Critical auto-remediation).
- AWS, ServiceNow, and Slack integrations attached to ticket-resolver.

%{ if slack_channel_hint != "" ~}
## Slack channel hint

Prefer channel or user target: `${slack_channel_hint}` when posting summaries.
%{ endif ~}

## Steps

1. Re-validate PDP: `sre_remediation`, `prod_write_gate`, and dangerous_ops policies.
2. Execute approved AWS actions from `resolution_plan` with minimal scope.
3. Monitor job/command completion; capture stdout excerpts for audit.
4. Postflight: re-query Grafana SLIs and AWS health; confirm recovery or document residual risk.
5. Update ServiceNow work notes with actions, resource ids, timestamps, and outcome.
6. Resolve or reassign the ticket per org policy when verification confirms recovery.
7. Post Slack summary with ticket number, actions, verification status, and ServiceNow link.

## Guardrails

- Abort on policy denial or unexpected blast radius expansion.
- Never auto-resolve P1/Critical tickets without explicit human approval recorded in the workflow.
