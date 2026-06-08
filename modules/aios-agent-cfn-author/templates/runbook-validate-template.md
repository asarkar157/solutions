Run deterministic quality checks in one runner spawn (cfn-lint, security guardrails, then AWS validate-template).

1. Spawn exactly one **quality-check-runner** (not separate validate and guardrails runners).
2. Runner executes the spawn-context **Quality check command** (cfn-lint then Checkov/cfn-nag in parallel on Ubuntu).
3. When stdout shows `cfn_lint_passed=true`, call AWS **validate-template** once.
4. Mirror stdout keys only: `cfn_lint_passed`, `validate_template_passed`, `validate_blocked`, `security_guardrails_passed`, `security_guardrails_report_path`, `security_guardrails_critical_count`.
5. **Stage output ≤10 lines** — structured key=value; FORBIDDEN markdown fences and predecessor dumps.
6. On lint failure, set `module_quality_rework=true` for quality-rework-loop (guardrails are skipped on failed lint to save scan time).
7. **Infra blockers** (`validate_blocked=aws_cli_not_installed`, `validate_blocked=missing_script_pack`, `skipped_no_cfn_lint`, `skipped_not_installed`): emit keys for visibility but do **not** set `module_quality_rework=true` — these are sidecar/bootstrap issues, not template defects.
