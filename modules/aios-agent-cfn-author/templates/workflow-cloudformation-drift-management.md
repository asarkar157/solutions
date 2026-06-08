Periodic and on-demand CloudFormation drift management across `${default_aws_regions}`.

When drift is detected, Aiden classifies each change:
- **FIX_DRIFT** — operational, compliance, or security risk (recommend remediation; no auto-fix in v1).
- **INCORPORATE_VIA_PR** — valid desired-state change → reconcile PR to the IaC repo.
- **IGNORE** — low-risk cosmetic drift.

Uses parallel batch detection, bounded retry on throttle, optional cron schedule, and optional HTTP webhook when `enable_drift_webhook = true`.

**Triggers:** Guild chat, schedule (`enable_drift_schedule`), or webhook with `drifted_stacks` JSON (see `docs/WEBHOOKS.md`).

**Skills:** `cfn-drift-scan-orchestration`, `cfn-drift-risk-classifier`, `cfn-drift-incorporate-pr`.
