# aios-cdk-validate-iam

Optional customer-account IAM role for **read-only CDK validation** (context lookups, `cdk diff` change-set preview). Does **not** create the Vault bastion — wire trust inputs from StackGen Vault config.

## Trust policy inputs

`external_id` and bastion principal are **workspace-stable** (not rotated when you swap customer roles). Fetch once per StackGen workspace:

- UI: Guild **Add integration → AWS → Step 1**
- API: `GET /v1/integration/aws/config?orgId=<project-uuid>`
- Terraform: `data.sg_vault_aws_config` (StackGen provider)

```hcl
data "sg_vault_aws_config" "workspace" {
  org_id = var.stackgen_project_id
}

module "cdk_validate_iam" {
  source = "github.com/appcd-dev/solutions//modules/aios-cdk-validate-iam?ref=main"

  trusted_assumer_arns = [data.sg_vault_aws_config.workspace.bastion_role_arn]
  external_id          = data.sg_vault_aws_config.workspace.external_id
  role_name            = "stackgen-cdk-validate"
}
```

Pass `role_arn` output to `aios-agent-cdk-bot` as `aws_role_arn` or bind via `existing_aws_integration_name` after Vault secret validation.

## Rotating the customer role

1. Create a replacement role with the **same** trust policy (`external_id` + bastion ARN unchanged).
2. Update `aws_role_arn` on the Vault secret / `aios-agent-cdk-bot` variable — not `external_id`.

See [stackgen-vault AWS credential rotation](https://github.com/appcd-dev/stackgen-vault/blob/main/docs/aws_credential_rotation.md).
