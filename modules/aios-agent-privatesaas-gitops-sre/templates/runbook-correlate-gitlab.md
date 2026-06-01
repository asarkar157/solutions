# Correlate GitLab signals

Read-only GitLab investigation for pipeline and MR context.

## Hints

- Default projects: ${gitlab_default_project_paths}
- Environment: ${private_saas_environment_label}

## Steps

1. Resolve project path from `normalized_request`.
2. Fetch latest pipeline status, failed jobs, and logs excerpt.
3. Link MR/commit SHA to deploy window.
4. Emit `gitlab_correlation` JSON with evidence URLs (no tokens).
