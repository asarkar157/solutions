End-to-end Grafana alert → Grafana/AWS/PAN-OS investigation → bounded AWS remediation pipeline for PrivateSaaS (private VPC).

## Trigger

- **Active**: Grafana webhook (`sg_webhook`) POST to StackGen when `enable_grafana_webhook = true`.
- **Passive**: Queries mentioning PrivateSaaS incidents, Grafana alerts, or firewall path analysis.

## Stages

1. **grafana-ingest-filter** — Deterministic Rego policy_check on the raw webhook payload (severity, environment/namespace allowlists; blocked alert names).
2. **normalize-alert** — Parse Grafana alert, enrich with labels/annotations, emit normalized JSON.
3. **collect-grafana-signals** — Query Grafana dashboards and Prometheus for incident-window metrics.
4. **correlate-aws-changes** — Inspect ECS/EKS/EC2 and CloudTrail around the incident window.
5. **analyze-firewall-path** — PAN-OS traffic/threat logs, policy hits, session analysis (read-only).
6. **synthesize-incident-report** — DevOps/SRE summary with network + infra correlation.
7. **remediation-safety-gate** — Inline Rego blocks auto-remediation when output reflects P1/SEV1-class severity.
8. **recommend-remediation** — Safe AWS actions only; firewall section = recommendations + change ticket text (no commits).

## Environment

PrivateSaaS environment label: `${private_saas_environment_label}`
