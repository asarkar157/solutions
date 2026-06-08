# AIOS — CloudFormation preview IAM

Optional AWS IAM role for **cfn-author** change-set preview and drift read. Keeps workload permissions out of Vault bastion IaC.

## Permissions

**Allow:** `CreateChangeSet`, `DescribeChangeSet`, `DeleteChangeSet`, `ValidateTemplate`, stack describe/list/get, drift detection read APIs.

**Deny:** `ExecuteChangeSet`, `CreateStack`, `UpdateStack`, `DeleteStack`, rollback/cancel mutations.

## Usage

```hcl
module "cfn_preview_iam" {
  source = "github.com/appcd-dev/solutions//modules/aios-cfn-preview-iam"

  trusted_assumer_arns = [
    "arn:aws:iam::111122223333:role/VaultTestBastionRole",
  ]
}

module "aws_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-aws"

  aws_role_arn = module.cfn_preview_iam.role_arn
  aws_region   = "us-east-1"
}
```

## Local Vault dev (two-step)

1. Apply `stackgen-vault/docs/aws-bastion` (bastion + read-only target).
2. Apply this module with `trusted_assumer_arns = [bastion_role_arn]`.
3. Re-apply bastion with `additional_target_role_arns = [module.cfn_preview_iam.role_arn]`.

Each new solution module can ship its own target role; bastion only needs the role ARN list updated — not solution-specific policy documents.

## Outputs

| Name | Description |
|------|-------------|
| `role_arn` | Guild / `aios-integration-aws` target role |
| `role_name` | IAM role name (display only — use `role_arn` for bastion `additional_target_role_arns`) |
| `policy_arn` | Attached managed policy |
