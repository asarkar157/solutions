Correlate CloudFormation failed resources with underlying AWS resource errors and service-level diagnostics.

## Steps

1. Load `stack_events_analysis` and `normalized_stack_event` from upstream stages.
2. For each failed logical resource, map CloudFormation type to AWS describe/list API calls (EC2, RDS, Lambda, IAM, S3, etc.).
3. Capture AWS-side error codes, throttling, quota limits, and permission denied messages.
4. Check CloudTrail for API errors around the failure window (±30 minutes).
5. Emit `aws_resource_correlation` JSON with per-resource AWS diagnostics and ranked root-cause hypotheses.

## Guardrails

- Read-only AWS API calls only.
- Do not modify resources or stack state during correlation.
