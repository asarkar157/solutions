Document a CloudFormation change set recommendation based on the infra RCA — do not execute prod changes without HITL.

## Steps

1. Confirm change-safety-gate passed (no blocked prod/production auto-changes).
2. Load `infra_rca_report` from upstream stages.
3. Draft `recommended_change_set` with: template diffs, parameter changes, required capabilities, expected replacements, and rollback plan.
4. For non-prod environments, optionally create and describe a change set when policy permits — await HITL before execute.
5. For prod/production, output documentation only — never execute change sets or stack updates without explicit approval.
6. **Never call delete-stack** — document manual deletion steps for operator approval if stack removal is truly required.

## Guardrails

- Prod/production requires HITL before any mutating CloudFormation action.
- delete-stack is forbidden without explicit operator approval in workflow input.
- Operate under sre_remediation and prod_write_gate policies.
