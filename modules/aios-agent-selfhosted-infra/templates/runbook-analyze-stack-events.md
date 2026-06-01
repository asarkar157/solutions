Analyze CloudFormation stack events for failed resources, rollback triggers, and status reason chains.

## Steps

1. Load `normalized_stack_event` from the prior stage.
2. Call `describe-stacks` for the target stack in the resolved region.
3. Call `describe-stack-events` (newest first) and filter for `FAILED`, `ROLLBACK_*`, and resource-level failure events.
4. Identify the earliest failing resource and subsequent rollback cascade.
5. Extract `ResourceStatusReason` messages for each failed logical resource.
6. Emit `stack_events_analysis` JSON with: failed resources, rollback reason, event timeline excerpt, and severity assessment.

## Guardrails

- Read-only CloudFormation and AWS calls only.
- Scope to the stack named in the normalized event unless policy allows broader inventory.
