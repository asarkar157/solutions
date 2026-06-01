GCP logging, metrics, and GKE investigation for PrivateSaaS.

Project: **${gcp_project_id}** | Region: **${gcp_region}**

## Steps

1. Run Cloud Logging queries scoped to service labels and incident window.
2. Pull Monitoring time series for golden signals.
3. Inspect GKE resources when kubernetes labels are present.
4. Note deploy/config change correlation.
5. Emit `gcp_investigation` JSON.

## Guardrails

- Read-only GCP operations.
