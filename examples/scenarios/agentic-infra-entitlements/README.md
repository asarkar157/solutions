# agentic-infra-entitlements

**Pitch:** Self-service infra with entitlement-sized IAM — CCE scans app repos before apply.

Requires AWS credentials + StackGen trust ARNs (see agentic-infrastructure README).

```bash
make demo SCENARIO=agentic-infra-entitlements
```

Ask the developer-request-intake workflow for an S3 bucket; CCE shows code calls `GetObject`/`PutObject` only.
