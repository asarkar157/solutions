# Alert Triage SOP

## Objective
Automatically enrich and triage incoming SIEM or Cloud security alerts to determine if they are false positives or require immediate escalation.

## Steps
1. **Extract Indicators**: Extract IPs, hashes, usernames, and resource ARNs from the incoming alert payload.
2. **Context Enrichment**:
   - Query Threat Intelligence sources for the extracted IPs/hashes.
   - Check the recent deployment history and IAM changes to see if this was a scheduled activity.
3. **Correlation**: Search across recent logs (e.g., CloudTrail, Kubernetes audit logs) for the same identity or IP over the last 24 hours.
4. **Classification**:
   - If the alert matches known benign behavior (e.g., vulnerability scanners), label as `False Positive`.
   - If anomalous activity is confirmed, label as `True Positive` and score the severity (Critical, High, Medium, Low).
5. **Notification**: Send a summary to the SecOps Slack channel with enriched context.
