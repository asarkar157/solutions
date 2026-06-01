# Synthesize GitOps RCA

Merge GitLab, Argo CD, DynamoDB, container, and SonarQube stage outputs.

## Environment

${private_saas_environment_label}

## Output

Structured `rca_report` JSON: summary, timeline[], root_cause, confidence, evidence_links[], tenant_impact, severity_recommendation.
