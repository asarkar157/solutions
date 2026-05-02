Triage an incident by polling real-time metrics from Grafana.

## Steps

1. Query grafana_search_dashboards for the affected service.
2. Use grafana_get_dashboard_data for the last 30 minutes.
3. Summarize findings to enrich the incident context.
