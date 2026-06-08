# CFN Author — webhook contracts

Remote systems invoke workflows via `sg_webhook` and StackGen `POST /api/v1/webhooks/trigger`. See module outputs for tokens and ingress URLs.

## Common fields

| Field | Required | Description |
|-------|----------|-------------|
| `intent` / `request` / `description` | Yes (one of) | Natural-language infrastructure request |
| `correlation_id` | No | Caller trace id (CI run, job id) |
| `workspace_id` | No | Logical workspace; defaults to module `workspace.workspace_id` or `target_repository_full_name` |
| `stack_name` | No | Target stack for change-set preview |
| `environment` | No | staging / production label |
| `template_file_name` | No | Output filename under `cfn_template_path_prefix` in the PR |
| `catalog_repo` | No | Upstream template library `org/repo` to clone for pattern discovery (read-only) |
| `github_repo_override` | No | PR target `org/repo` when different from `target_repository_full_name` |
| `confirm_deploy` | No | `"true"` → run change-set preview after PR; `"false"` → PR / report only (default safe path) |

## Intent to infrastructure

Webhook name: `cfn-intent-to-infrastructure` (when `enable_intent_webhook = true`).

```json
{
  "intent": "Provision a private S3 bucket with versioning enabled, SSE-S3 default encryption, and a bucket policy that denies public ACLs and unencrypted uploads. Target us-east-1 for the staging data plane.",
  "stack_name": "staging-data",
  "environment": "staging",
  "template_file_name": "staging-data-s3-versioning.yaml",
  "workspace_id": "org/infra-templates",
  "correlation_id": "cfn-author-demo-20260607",
  "confirm_deploy": "true"
}
```

**External catalog reference:** set `catalog_repo` to the upstream library (e.g. `aws-cloudformation/aws-cloudformation-templates`) and `github_repo_override` to **your** repo where the PR should land.

## Contextual compliance

Webhook name: `cfn-contextual-compliance` (when `enable_compliance_webhook = true`).

```json
{
  "intent": "Private RDS instance in us-east-1 with encryption",
  "environment": "production",
  "correlation_id": "gate-456"
}
```

Response stage emits `compliance_report` JSON per [compliance-report-schema.json](./compliance-report-schema.json).

## Drift management

Webhook name: `cfn-drift-management` (when `enable_drift_webhook = true`).

For local Guild runs, stacks must match module `stack_prefix` (often `staging-`) or pass explicit `stack_names`. Empty inventory completes in under two minutes without batch runner fan-out.

```json
{
  "correlation_id": "drift-scan-789",
  "workspace_id": "org/infra-templates",
  "drifted_stacks": [
    { "stack_name": "staging-vpc", "region": "us-east-1", "environment": "staging" },
    { "stack_name": "staging-data", "region": "us-east-1", "environment": "staging" }
  ],
  "confirm_deploy": "false"
}
```

## Skills sync

Register skills from [`../skills/`](../skills/) via Guild skill source (git path to this module's `skills/` directory). Workflow `skill_refs` list names in output `recommended_skill_names`.

After `tofu apply`, recycle the cfn-author **Ubuntu sidecar** when `script_pack_version` changes so validate / quality-check / open-pr runners load the embedded script pack.
