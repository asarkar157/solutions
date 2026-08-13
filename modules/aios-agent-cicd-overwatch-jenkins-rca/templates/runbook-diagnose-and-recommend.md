Classify the failure and recommend the smallest safe fix from the collected evidence.

## Steps

1. Classify the primary failure as one of: Jenkins/controller health, source/contract, or artifact/registry/AWS.
2. Use the exact Git commit Jenkins resolved (not the current branch head) when checking source/contract evidence.
3. Check at least one alternative explanation and state why it's less likely.
4. If AWS/GitHub evidence would help but the integration isn't attached, record that as an explicit evidence gap.
5. Recommend the smallest safe fix and concrete verification steps.
6. State whether the fix requires remediation approval.

## Output schema

Emit `diagnosis` with `failure_class`, `evidence_chain[]`, `alternatives_considered[]`, `recommended_fix`, `verification_steps[]`, `requires_approval`.
