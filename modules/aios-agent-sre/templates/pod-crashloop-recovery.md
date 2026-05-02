Recover a CrashLoopBackOff pod without service disruption.

## Steps

1. `kubectl describe pod` to capture exit code,
2. `kubectl logs --previous` to extract root cause,
3. If OOMKilled, check memory limits vs usage,
4. If config error, verify ConfigMap/Secret mounts,
5. Apply fix,
6. Monitor pod restart count for 10 min.
