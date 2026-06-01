# Recommend remediation and notify Slack

Post bounded remediation plan to ${slack_notify_channel_hint}.

## Rules

- Argo CD sync retry: recommend only; HITL for execution.
- npm: propose audit fix / dependency PR — no production install without approval.
- GitLab: no merge/push without HITL.
- Include numbered steps, risks, and explicit HITL callouts.
