---
name: cfn-template-catalog-discovery
description: Locate and summarize reusable templates in the company CloudFormation catalog.
---

# CFN template catalog discovery

1. Read `WORK_ROOT/generated/catalog_candidates.json` produced by parse-intent (catalog-discover.sh).
2. When the top candidate score ≥ 3, **must** cite that catalog path before greenfield synthesis.
3. Match intent keywords (S3, RDS, VPC, Lambda) to catalog template names when the JSON file is absent.
4. Return candidate template paths with a one-line rationale for reuse vs greenfield.
5. Do not copy entire templates into chat — cite paths only.
