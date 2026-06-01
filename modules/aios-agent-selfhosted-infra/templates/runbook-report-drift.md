Report CloudFormation drift audit findings with prioritized remediation recommendations.

## Steps

1. Load `stack_inventory` and `drift_findings` from upstream stages.
2. Summarize drift by environment, stack, and resource type.
3. Rank stacks by drift severity (prod/production stacks first).
4. Recommend read-only vs. change-set remediation paths for each drifted stack.
5. Emit `drift_audit_report` JSON with executive summary and per-stack detail.

## Guardrails

- Report only — no stack updates or drift remediation during audit workflow.
