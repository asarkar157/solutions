Validate CloudFormation template intent before a proposed deploy (read-only pre-deploy review).

## Steps

1. Accept template source: S3 URL, inline template body, or existing stack name for `get-template`.
2. Parse resources, parameters, outputs, and conditions.
3. Verify resource types and counts match the stated deployment intent.
4. Check for hard-coded environment values, missing parameters, and unsafe defaults.
5. Optionally run `cfn-lint` via Ubuntu CLI when enabled.
6. Emit `template_intent_review` JSON with validation findings and deploy readiness assessment.

## Guardrails

- Read-only — do not create or update stacks during pre-deploy review.
- cfn-lint is optional when Ubuntu CLI is unavailable.
