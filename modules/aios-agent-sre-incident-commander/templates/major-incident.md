# Major Incident Response SOP

1. **Acknowledge**: Accept PagerDuty page. Create a dedicated incident Slack channel.
2. **Diagnose**: Query Datadog APM for highest latency and error rate changes.
3. **Mitigate**: If a bad deployment is found, execute a rollback of the Kubernetes Deployment. Otherwise, scale up resources if CPU exhausted.
4. **Postmortem**: After resolution, compile timeline logs, metrics graphs, and mitigation steps into a Postmortem Markdown document.
