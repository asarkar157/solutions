Generic GCP investigation playbook for PrivateSaaS workloads.

- **GCP project**: ${gcp_project_id}
- **Region hint**: ${gcp_region}
- **Environment**: ${private_saas_environment_label}

## Steps

1. Scope Cloud Logging queries to incident window ±15 minutes around `fired_at`.
2. Pull relevant Monitoring metrics (latency, error rate, saturation) for labeled service.
3. When `cluster` or `namespace` labels exist, inspect GKE workload events and pod status (read-only).
4. Correlate deploy/restart events with incident start time.
5. Emit `gcp_signals` JSON with log excerpts, metric deltas, and resource ids.

## Guardrails

- Read-only GCP APIs unless explicit HITL approval exists.
- Redact service account keys and secrets from output.
