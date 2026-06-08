# CloudFormation template catalog

Reference templates for [`aios-agent-cfn-author`](../../modules/aios-agent-cfn-author/). The intent-to-infrastructure workflow discovers this directory via `cfn_template_catalog_path` (default `cloudformation/catalog/`) and reuses patterns before synthesizing new resources.

## Layout

| File | Purpose |
|------|---------|
| `s3-versioned-bucket.yaml` | Baseline private S3 bucket with versioning and encryption |
| `README.md` | Catalog index (this file) |

Add org-specific templates here; keep filenames stable so catalog-discovery skill can reference them by name.
