Coordinate parallel drift detection across stack batches.

1. Read `stack_count` from upstream inventory notes or `[Workflow notes from prior stage]`. When `stack_count=0`, `note("drift_scan_complete", "true")` and **do not spawn** batch runners — inventory-empty-gate already short-circuited the workflow.
2. Split stack_inventory into batches of ${drift_detection_batch_size} stacks; write batch_payloads.json.
3. Spawn drift-detect-runner-batch-01 … batch-04 in ONE parallel create_agent message.
4. Fan-in partial drift_findings; note `drift_retry_stack_ids` for throttled stacks.
5. Set `drift_scan_complete: "true"` when all batches finish or `blocked:parallel_drift_failed` on total failure.

**Local demo:** drift webhook needs stacks matching `stack_prefix` (default `staging-`) or explicit `stack_names` in the payload.
