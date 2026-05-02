Builds, scans, tests, and deploys a service from a Git ref to production — with parallel security scanning and integration testing, progressive canary rollout, automatic rollback on failure, and human-in-the-loop approval before production promotion.

Terraform may set `approve = true` on this workflow so the Guild **workflow version** leaves draft after apply; that does **not** skip operator approval for production promotion described in the pipeline stages.
