Correlate AWS infrastructure changes with a PrivateSaaS incident window.

## Steps

1. Load `normalized_alert` and `grafana_signals` from prior stages.
2. Identify affected AWS resources from alert labels and Grafana context (ECS cluster/service, EKS namespace, EC2 instance IDs).
3. Query ECS/EKS deployment history, EC2 instance state, and Auto Scaling activity for the ±15 minute incident window.
4. Search CloudTrail for mutating API calls (deployments, scaling, security group changes) in the affected accounts/regions.
5. Emit `aws_correlation` JSON with change timeline, suspect events, and resource health snapshots.

## Guardrails

- Read-only AWS queries during investigation.
- Scope to the PrivateSaaS environment label and configured AWS account hints.
