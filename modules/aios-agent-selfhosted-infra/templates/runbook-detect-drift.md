Detect CloudFormation drift for inventoried stacks.

## Steps

1. Load `stack_inventory` from the prior stage.
2. For each stack, call `detect-stack-drift` and poll `describe-stack-drift-detection-status` until complete.
3. Call `describe-stack-resource-drifts` for stacks with drift detected.
4. Emit `drift_findings` JSON with per-stack drift status and drifted resource details.

## Guardrails

- Drift detection is read-only — do not execute drift remediation during audit.
