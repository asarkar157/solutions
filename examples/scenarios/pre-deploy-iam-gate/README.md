# pre-deploy-iam-gate

**Pitch:** Block IAM surprises at PR time — CCE posts file:line evidence for new cloud API call sites.

## Talk track

1. Open a PR that adds `s3:GetObject` in application code.
2. Trigger `pre-deploy-iam-review` workflow (GitHub PR webhook).
3. Show PR comment with entitlement table and suggested minimal IAM action.

```bash
make demo SCENARIO=pre-deploy-iam-gate
```
