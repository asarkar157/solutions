End-to-end CloudFormation stack failure → investigation → change-set recommendation pipeline for self-hosted AWS infrastructure.

## Trigger

- **Active**: CloudFormation failure webhook (`sg_webhook`) POST to StackGen when `enable_stack_failure_webhook = true`.
- **Passive**: Queries mentioning CloudFormation stack failures, rollback, or infra RCA.

## Stages

1. **stack-ingest-filter** — Deterministic Rego policy_check (stack prefix allowlist, blocked stacks, environment tag).
2. **normalize-stack-event** — Parse stack failure payload, emit normalized JSON.
3. **analyze-stack-events** — Failed resources and rollback reasons from stack events.
4. **correlate-aws-resources** — Underlying AWS resource errors for failed logical resources.
5. **review-template** — Template body, parameters, and policy issues.
6. **synthesize-infra-rca** — Cross-signal RCA synthesis.
7. **change-safety-gate** — Inline Rego blocks prod/production auto-changes.
8. **recommend-change-set** — Document change set; do not execute in prod without HITL.

## Environment

Self-hosted environment label: `${self_hosted_environment_label}`

Stack hints: ${cloudformation_stack_hints}
