Read-only DevOps connectivity audit across Grafana, AWS networking, and Palo Alto PAN-OS policies for PrivateSaaS.

## Trigger

- **Passive**: Scheduled or on-demand queries for PrivateSaaS connectivity health checks.

## Stages

1. **grafana-health-snapshot** — Grafana datasource health, firing alerts, notification channel status.
2. **aws-network-snapshot** — VPC/subnet/route/security group topology and endpoint health.
3. **firewall-policy-review** — PAN-OS policy inventory, hit counts, and hygiene findings (read-only).

## Environment

PrivateSaaS environment label: `${private_saas_environment_label}`
