Perform policy sanity checks on a CloudFormation template before deploy (IAM, security groups, public exposure).

## Steps

1. Load `template_intent_review` from the prior stage (or fetch template directly).
2. Scan for overly permissive IAM policies (`Action: *`, `Resource: *`), open security group rules (`0.0.0.0/0`), and public S3 buckets.
3. Verify encryption settings on RDS, S3, EBS, and other data stores when present.
4. Check for missing deletion policies on stateful resources.
5. Emit `policy_sanity_report` JSON with findings, severity, and recommended template fixes.

## Guardrails

- Read-only policy analysis — no stack creation or IAM changes during review.
