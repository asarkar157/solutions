# Review pattern — high-throughput web

**Trigger:** `workload_class=high-throughput-web` or `target_rps` ≥ 100,000 in `requirements_spec.json`.

## Critical

| ID | Check | Remediation |
|----|-------|-------------|
| `asg-wrong-scaling-metric` | `EC2SpotFleetRequestAverageCPUUtilization` on standard ASG | Use `ASGAverageCPUUtilization` |
| `high-rps-without-edge-scale` | 1M+ RPS with ALB-only, no CloudFront/NLB/pre-warm note | Add edge tier or document pre-warm |

## Warning

| ID | Check | Remediation |
|----|-------|-------------|
| `missing-vpc-endpoints` | Private subnets + NAT, no Interface endpoints | Add PrivateLink for SSM/Secrets/SQS/Logs |
| `asg-capacity-vs-rps` | MaxSize too small for declared RPS | Increase MaxSize or instance size |
| `aurora-reader-autoscaling` | Single reader on read-heavy workload | Aurora Auto Scaling for replicas |
| `shared-cmk-blast-radius` | One CMK for logs+secrets+data+queues | Segment keys by tier |
| `static-az-index` | `!Select [0, !GetAZs]` subnet pinning | Parameterize AZ list |
| `alb-logs-sse-s3-only` | ALB logs bucket SSE-S3 under FedRAMP moderate | SSE-KMS with CMK |

Implemented in `scripts/architecture-lint.sh` — extend this doc when new review feedback arrives.
