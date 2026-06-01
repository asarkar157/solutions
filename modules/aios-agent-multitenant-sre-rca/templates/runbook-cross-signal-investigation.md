Cross-signal investigation for a multi-tenant Datadog alert using Datadog, GCP Cloud Logging, AWS ECS, CloudTrail, and GitHub.

## Prerequisites

- `normalized_alert` JSON from the normalize-alert stage with `tenant_id`, `service`, and `fired_at`.
- Datadog integration for metrics, logs, monitors, and APM traces.
- GCP integration for Cloud Logging in project `${gcp_project_id}` (region `${gcp_region}`).
- AWS integration for ECS deployment history and CloudTrail.
- GitHub integration for commit history on repos: ${github_default_repos} (org hint: `${github_default_org}`).

## Steps

1. **Time window** — Anchor investigation ±15 minutes around `fired_at`; extend to ±30 minutes if deploy correlation is suspected.
2. **Datadog sweep** — Pull related monitors, error-rate metrics, log patterns, and trace errors filtered by tenant tag `${tenant_tag_key}` and service tags.
3. **GCP Cloud Logging** — Query structured logs with tenant_id filter; inspect error spikes, stack traces, and upstream dependency failures.
4. **AWS ECS deploy history** — Use cluster hints ${aws_ecs_cluster_hints} to describe-services and list service events/deployment timestamps for the affected service.
5. **AWS CloudTrail** — lookup-events for RunTask, UpdateService, RegisterTaskDefinition, and IAM changes in the investigation window.
6. **GitHub correlation** — git log and blame on suspect paths in default repos; match commit SHAs to deploy timestamps.
7. **Correlate** — Join signals across sources; rank hypotheses by confidence with supporting excerpts.
8. **Evidence bundle** — Emit `investigation_report` with `hypotheses[]`, `evidence[]`, `deploy_correlation`, and `severity_recommendation`.

## Output schema

Return `investigation_report` with ranked hypotheses, cross-signal evidence links, and tenant-scoped findings only.
