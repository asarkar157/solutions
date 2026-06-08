Run deterministic CloudFormation security guardrails before opening a PR.

Uses open-source scanners (**Checkov**, **cfn-nag**) via the embedded script pack on the Ubuntu integration. Output is a stable JSON report at `generated/security-guardrails-report.json`.

1. Spawn exactly one **security-guardrails-runner**.
2. Runner executes the spawn-context **Security guardrails command** (installs script pack, runs `stage-runner.sh security-guardrails`).
3. Mirror stdout keys: `security_guardrails_passed`, `security_guardrails_report_path`, `security_guardrails_critical_count`, `checkov_status`, `cfn_nag_status` (and legacy `policy_scan_passed`).
4. On `security_guardrails_passed=false` with critical findings, the workflow skips PR at `security-guardrails-blocked-gate`.

Report schema: [`docs/security-guardrails-report.schema.json`](./security-guardrails-report.schema.json).
