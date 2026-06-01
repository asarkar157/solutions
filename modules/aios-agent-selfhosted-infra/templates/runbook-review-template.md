Review the CloudFormation template body, parameters, and policy issues contributing to the stack failure.

## Steps

1. Load upstream analysis artifacts (`stack_events_analysis`, `aws_resource_correlation`).
2. Call `get-template` (or `get-template-summary`) for the target stack.
3. Inspect parameters, conditions, mappings, and the failed resource definition in the template.
4. Check for missing `CAPABILITY_IAM` / `CAPABILITY_NAMED_IAM`, circular dependencies, and invalid property values.
5. Optionally run `cfn-lint` via Ubuntu CLI when enabled — not required for RCA completion.
6. Emit `template_review` JSON with template issues, parameter mismatches, and recommended template fixes.

## Guardrails

- Read-only template fetch; do not upload or update templates during review.
- cfn-lint is optional — skip when Ubuntu CLI is unavailable.
