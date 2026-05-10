# Proactive Threat Hunt SOP

## Objective
Proactively search through infrastructure logs to identify dormant or active threats that bypassed signature-based detection.

## Steps
1. **Hypothesis Generation**: Based on recent CVEs, Threat Intel reports, or known MITRE ATT&CK techniques, define a search hypothesis (e.g., "Attackers are abusing misconfigured IAM roles to access S3 buckets").
2. **Log Queries**:
   - Execute queries against the centralized logging platform.
   - Look for anomalous API calls (`Describe`, `List`, `Get`) from unusual IPs or without MFA.
3. **Behavioral Analysis**: Identify lateral movement attempts or privilege escalation patterns within the results.
4. **Validation**: Validate findings against asset context (e.g., Is this a bastion host?).
5. **Reporting**: Generate a Threat Hunt report with findings, IoCs, and remediation recommendations.
