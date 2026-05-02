Roll back a failing ArgoCD deployment to last known good revision.

## Steps

1. Identify last healthy sync revision,
2. Trigger rollback,
3. Monitor rollout status,
4. Validate error rate drops below SLO threshold,
5. Notify #releases channel,
6. Create post-mortem ticket if regression escaped staging.
