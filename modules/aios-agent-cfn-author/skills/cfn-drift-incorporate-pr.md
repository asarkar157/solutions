---
name: cfn-drift-incorporate-pr
description: Open a GitHub PR that reconciles CloudFormation templates with incorporated drift.
---

# CFN drift incorporate PR

1. Run only when classification includes INCORPORATE_VIA_PR items and remediation PR is enabled.
2. Draft template diffs under the workspace path prefix on a feature branch.
3. Open PR against the workspace base branch with drift summary and stack list in the body.
4. Never execute stack updates — PR only.
