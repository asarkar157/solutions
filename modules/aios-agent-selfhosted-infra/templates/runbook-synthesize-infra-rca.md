Synthesize a self-hosted infrastructure RCA report from stack events, AWS correlation, and template review.

## Steps

1. Load `stack_events_analysis`, `aws_resource_correlation`, and `template_review` from upstream stages.
2. Rank root-cause hypotheses with confidence scores and supporting evidence excerpts.
3. Document blast radius: affected resources, dependent stacks, and environment impact.
4. Recommend immediate containment steps (read-only) vs. change-set remediation paths.
5. Emit `infra_rca_report` JSON with: summary, root cause, evidence, blast radius, and recommended next actions.

## Guardrails

- Investigation synthesis only — no mutating CloudFormation or AWS actions.
- Clearly label prod/production impact for downstream change-safety-gate.
