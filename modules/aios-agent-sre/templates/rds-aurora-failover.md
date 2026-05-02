Promote Aurora read-replica to primary in us-west-2.

## Steps

1. Verify replica lag < 5 s via CloudWatch ReplicaLag metric,
2. Enable DNS failover in Route 53 health check,
3. Issue `aws rds failover-db-cluster --db-cluster-identifier checkout-prod`,
4. Validate write path within 30 s,
5. Notify #incident Slack channel with failover timestamp and new writer endpoint.
