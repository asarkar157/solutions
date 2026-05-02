Activate Route 53 DNS failover to secondary region.

## Steps

1. Confirm primary region health check is failing,
2. Verify secondary region is healthy,
3. Update failover record set,
4. Set TTL to 60 s during incident,
5. Monitor DNS resolution,
6. Restore original TTL after recovery.
