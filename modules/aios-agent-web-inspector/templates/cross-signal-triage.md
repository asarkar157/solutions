Correlate user-facing browser errors with backend signals from Grafana, GitHub, and OS-level diagnostics.

## Steps

1. Navigate to the affected page: USE `navigate_page` with the reported URL
2. Capture initial state: USE `take_screenshot`
3. Gather frontend signals:
   a. Console errors: USE `list_console_messages` — note error messages and stack traces
   b. Failed network requests: USE `list_network_requests` — identify 4xx/5xx API calls
   c. Get request details: USE `get_network_request` for each failed request
   d. DOM state: USE `evaluate_script` with `document.querySelector('.error-boundary')?.textContent`
4. If Grafana integration is available — gather backend signals:
   a. Query error rate metrics for the failing endpoint
   b. Check backend latency for the service
   c. Look for correlating alerts
5. If GitHub integration is available — gather source context:
   a. Search for recent commits related to the failing endpoint
   b. Check recent PR merges that could have introduced the issue
6. If Ubuntu CLI is available — gather infrastructure signals:
   a. Check DNS resolution for the backend service
   b. Verify network connectivity to dependent services
7. Cross-correlate: map frontend error timestamps to backend metric spikes
8. **Output:** Root cause analysis report with:
   - Timeline of events (frontend error → backend correlation)
   - Screenshots showing user-visible impact
   - Console errors with stack traces
   - Failed API calls with response details
   - Backend metric anomalies (if Grafana available)
   - Likely root cause and blast radius assessment
   - Recommended remediation steps
