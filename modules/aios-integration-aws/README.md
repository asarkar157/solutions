# aios-integration-aws

Provisions an AWS cloud integration with JIT credentials via Vault IAM role assumption.

## Prerequisites (IAM trust)

Before the integration can assume your role, configure IAM in **your** AWS account:

1. Fetch workspace setup values: Guild **Add integration → AWS → Step 1**, `GET /v1/integration/aws/config?orgId=<project-uuid>`, or Terraform `data.sg_vault_aws_config`.
2. Create or update a customer IAM role whose trust policy uses:
   - **Principal:** StackGen bastion `roleArn` / `bastion_role_arn` from the config API (not your `aws_role_arn`).
   - **`sts:ExternalId`:** workspace `externalId` / `external_id` — **stable per workspace**; reuse when rotating roles.
3. Pass the customer role ARN as `aws_role_arn` below (or via an existing Vault secret).

See [stackgen-vault AWS credential rotation](https://github.com/appcd-dev/stackgen-vault/blob/main/docs/aws_credential_rotation.md).

## Usage

```hcl
data "sg_vault_aws_config" "workspace" {
  org_id = var.stackgen_project_id
}

# Optional: manage the customer role in your account (trust_policy from data source).
# resource "aws_iam_role" "stackgen_access" {
#   name               = "stackgen-aws-integration"
#   assume_role_policy = data.sg_vault_aws_config.workspace.trust_policy
# }

module "aws_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-aws?ref=main"

  aws_role_arn = "arn:aws:iam::123456789012:role/SREReadOnly" # rotatable — update on role swap
  aws_region   = "us-west-2"
}
```

## Rotating credentials

| Change | Action |
|--------|--------|
| New customer role (blue/green) | Same trust policy (bastion + external ID) → update `aws_role_arn` / `sg_secret.metadata.aws_role_arn` only |
| Permission changes | Edit IAM policies on the role; no Vault change |
| Workspace external ID | Do **not** rotate routinely — StackGen-controlled confused-deputy binding |

## What It Creates

| Resource | Description |
|----------|-------------|
| `sg_secret` | Vault secret storing the AWS role ARN and region |
| `sg_guild_integration` | Containerized AWS CLI MCP integration |

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `integration_id` | Integration resource ID |
| `secret_id` | Vault secret ID |
