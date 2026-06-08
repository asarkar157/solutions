---
name: cfn-architecture-fit-review
description: Post-synthesis architecture and NFR fit review against generated CloudFormation.
---

# CFN architecture fit review

Use after **quality-check** when `WORK_ROOT/generated/template.yaml` exists.

1. Read `WORK_ROOT/requirements_spec.json` for NFRs: `target_rps`, `sla_availability`, `p99_latency_ms`, `workload_class`, `environment`.
2. Spawn **architecture-fit-runner** — ONE execute_series runs deterministic `architecture-lint.sh`.
3. Read `WORK_ROOT/generated/architecture-findings.json` — do not re-derive findings in prose.
4. Mirror stdout: `architecture_lint_passed=`, `architecture_summary=` (PASS|NEEDS_REVIEW|FAIL), `architecture_critical_count=`, `architecture_findings_path=`.
5. On **FAIL** (`architecture_summary=FAIL`): emit `architecture_blocked=true` — PR gate will skip open-pr.
6. On **NEEDS_REVIEW**: emit `architecture_needs_review=true` — PR may open with findings in script-rendered body.
7. **Stage output ≤10 lines** — structured key=value only.

## Pattern library

Load review patterns from `${knowledge_base_path}` and `docs/cfn-author/review-patterns/` when synthesizing or remediating:

- **high-throughput-web** — RPS ≥ 100k: edge scale (CloudFront/NLB), ASG metric correctness, capacity vs MaxSize, Aurora reader scaling.
- **fedramp-moderate** — SSE-KMS on log buckets, VPC endpoints for private tiers, KMS segmentation.

## Synthesis guardrails (apply in synthesize-template when NFRs present)

- Never use `EC2SpotFleetRequestAverageCPUUtilization` on standard `AWS::AutoScaling::AutoScalingGroup`.
- High RPS intents require documented edge strategy or lower declared RPS.
- Private app tiers: Interface VPC Endpoints for SSM, Secrets Manager, SQS, CloudWatch Logs.
- Parameterize Availability Zones — avoid blind `!Select [0, !GetAZs]`.
