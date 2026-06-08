Post-synthesis architecture and NFR fit review — validates **generated YAML** against `requirements_spec.json`, not intent prose alone.

1. Spawn exactly one **architecture-fit-runner** using the spawn-context **Architecture lint command**.
2. Read `WORK_ROOT/generated/architecture-findings.json` after the runner completes.
3. Mirror stdout keys only: `architecture_lint_passed=`, `architecture_summary=`, `architecture_critical_count=`, `architecture_warning_count=`, `architecture_findings_path=`.
4. On `architecture_summary=FAIL`, emit `architecture_blocked=true` (critical findings — PR blocked).
5. On `architecture_summary=NEEDS_REVIEW`, emit `architecture_needs_review=true` (PR allowed; findings appended to PR body by script).
6. **Stage output ≤10 lines** — FORBIDDEN: full template replay, read_notes dumps.

Deterministic checks include: ASG scaling metric mismatch, static AZ indices, missing VPC endpoints with NAT, FedRAMP SSE-KMS on log buckets, high-RPS without edge scale, ASG MaxSize vs RPS, shared CMK blast radius, Aurora reader autoscaling gaps.
