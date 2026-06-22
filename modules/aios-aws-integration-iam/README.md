# aios-aws-integration-iam

Optional customer-account IAM role for **read-only** StackGen AWS MCP integrations (`aios-integration-aws`, SRE scenarios).

## Trust policy

The module builds the customer role trust policy from Vault workspace values — bastion principal, `sts:ExternalId` on `AssumeRole`, and a separate `sts:TagSession` statement (same shape as Guild **Add integration → AWS → Step 1**).

```hcl
data "sg_vault_aws_config" "workspace" {
  org_id = var.stackgen_project_id
}

module "aws_iam" {
  source = "github.com/appcd-dev/solutions//modules/aios-aws-integration-iam?ref=main"

  role_name        = "stackgen-aios-readonly"
  bastion_role_arn = data.sg_vault_aws_config.workspace.bastion_role_arn
  external_id      = data.sg_vault_aws_config.workspace.external_id
}

module "aws_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-aws?ref=main"

  aws_role_arn = module.aws_iam.role_arn
  aws_region   = "us-east-1"
}
```

`data.sg_vault_aws_config.workspace.trust_policy` is the same JSON for copy/paste in the AWS console; this module encodes it in Terraform so the created role is always correct.

## Bastion allowlist

StackGen’s bastion IAM (StackGen AWS account) must allow `sts:AssumeRole` to your customer role ARN. That allowlist is **managed by StackGen** — customer Terraform must not mutate the bastion account.

Creating a new customer role (this module) only updates **your** account. After apply, ask StackGen to add `role_arn` to the bastion allowlist, or use a role that is already allowlisted before registering the Vault secret.

## Rotating the customer role

Create a replacement role with the same `bastion_role_arn` and `external_id`, update `aws_role_arn` on the Vault secret — `external_id` does not change per workspace.
