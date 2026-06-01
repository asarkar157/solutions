# Assess SonarQube

Read-only quality gate and new-issue review.

## Hints

- Project keys: ${sonarqube_project_keys}
- Environment: ${private_saas_environment_label}

## Steps

1. Resolve project key from branch or request.
2. Fetch quality gate status and new issues on the branch.
3. Correlate gate failure with pipeline/deploy timing.
4. Emit `sonarqube_assessment` JSON.
