---
name: cfn-drift-scan-orchestration
description: Scope and batch CloudFormation drift detection across stacks and regions.
---

# CFN drift scan orchestration

1. Resolve regions, stack prefixes, explicit stack names, and environment filters from scope notes.
2. For webhook ingress, honor `drifted_stacks` when already normalized upstream.
3. Batch stacks for parallel detect subagents; respect configured batch size.
4. Track throttled stacks for retry loop; emit `drift_scan_complete: true` when finished.
