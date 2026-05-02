Gracefully drain and restart ElastiCache Redis cluster nodes.

## Steps

1. Set cluster to maintenance mode,
2. Enable AOF persistence,
3. Drain connections from target node,
4. Wait for active connection count to reach 0,
5. Restart node,
6. Re-add to target group,
7. Validate cache hit ratio returns above 90% within 5 min.
