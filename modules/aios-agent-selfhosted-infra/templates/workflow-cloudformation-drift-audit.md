Read-only CloudFormation drift audit across configured AWS regions for self-hosted infrastructure.

## Stages

1. **inventory-stacks** — List active and failed stacks per region.
2. **detect-drift** — Run drift detection and collect drifted resources.
3. **report-drift** — Summarize findings with prioritized remediation recommendations.

## Environment

Self-hosted environment label: `${self_hosted_environment_label}`
Default regions: ${default_aws_regions}
