---
name: cfn-company-best-practices
description: Apply organisational CloudFormation catalog, NFR-aware synthesis, and architecture anti-patterns during template generation.
---

# CFN company best practices

1. Read `WORK_ROOT/requirements_spec.json` for NFRs (`target_rps`, `workload_class`, `environment`) before authoring resources.
2. Search the template catalog under the workspace path before greenfield resources — compose from approved patterns when matched.
3. Reuse approved patterns (VPC + Interface endpoints, ALB+WAF, Aurora with reader scaling) from catalog entries.
4. Apply standard tags, naming prefixes, and region constraints from catalog README.
5. Prefer parameterized, composable modules over one-off resource blocks.

## Architecture anti-patterns (never ship without remediation or NEEDS_REVIEW)

- **ASG scaling metric:** `ASGAverageCPUUtilization` for standard ASG — never `EC2SpotFleetRequestAverageCPUUtilization` unless using Spot Fleet.
- **High RPS:** When `target_rps` ≥ 100k, include CloudFront/NLB edge strategy or document ALB pre-warm assumption.
- **Private tiers:** NAT-only egress to AWS APIs — add Interface VPC Endpoints for SSM, Secrets Manager, SQS, CloudWatch Logs.
- **FedRAMP moderate:** Log and audit buckets use SSE-KMS (CMK), not SSE-S3 only.
- **AZ selection:** Parameterize `AvailabilityZones` — avoid hard-coded `!Select [0, !GetAZs]`.
- **KMS segmentation:** Separate CMKs for data, messaging, and logging tiers when encrypting 3+ service classes.

See `docs/cfn-author/review-patterns/high-throughput-web.md` and skill `cfn-architecture-fit-review`.
