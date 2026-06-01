Synthesize a DevOps/SRE incident report with network and infrastructure correlation.

## Steps

1. Load `normalized_alert`, `grafana_signals`, `aws_correlation`, and `firewall_path_analysis` from prior stages.
2. Correlate Grafana metrics, AWS change events, and firewall path findings into a unified timeline.
3. Rank hypotheses (deploy regression, capacity, config drift, firewall deny, dependency failure, external).
4. Assign recommended severity and blast radius for the PrivateSaaS environment (`${private_saas_environment_label}`).
5. Emit `incident_report` JSON with: timeline, top hypotheses with evidence, affected services, network path summary, and remediation category hints.

## Guardrails

- Evidence-based synthesis only — cite specific log/metric excerpts.
- Flag firewall-related root causes separately from AWS infra causes.
