Recommend safe AWS remediation and firewall change-ticket text for a PrivateSaaS incident.

## Steps

1. Confirm remediation-safety-gate passed.
2. Load `incident_report` JSON from upstream stages.
3. Plan bounded AWS actions permitted by policy: ECS force-new-deployment, ASG scale, target group adjustments — with rollback steps.
4. For firewall-related findings, draft `firewall_recommendations` with proposed rule changes, affected zones, and verification steps as **change-ticket text only**.
5. Execute approved AWS actions; capture output and post-action health checks via Grafana.
6. Emit `remediation_summary` JSON with AWS actions taken, firewall recommendations (no commits), and verification status.

## Guardrails

- **NO PAN-OS rule pushes** — firewall section is recommendations and change-ticket text only.
- P1/SEV1 requires human approval (enforced upstream by remediation-safety-gate).
- Abort when blast radius exceeds one PrivateSaaS environment without explicit approval.
