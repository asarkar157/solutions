# Scenario: `cfn-author`

## Pitch

> "Developers describe infrastructure in plain language. Aiden reads your CloudFormation catalog, generates a company-standard template, opens a PR, and previews the change set — all on Bedrock Sonnet 4.6. A separate drift workflow scans stacks on a schedule, flags security risks, and opens reconcile PRs when drift is valid desired state."

## What this scenario wires

- `aios-foundation-bedrock` — Claude Sonnet 4.6 in `us-east-1` only
- `aios-policies` — dangerous_ops + prod_write_gate
- `aios-integration-github` + `aios-integration-aws`
- `aios-agent-cfn-author` — four workflows (intent, drift, compliance, governed deployment) + optional webhooks and drift cron
- Optional `aios-cfn-preview-iam` — change-set preview + drift read target role (see IAM below)

## AWS IAM (change-set preview)

`ReadOnlyAccess` and generic Vault bastion targets do **not** include `cloudformation:CreateChangeSet`. Use `modules/aios-cfn-preview-iam` (or your own role with the same allow/deny shape).

**Production:** pass an existing `aws_role_arn`.

**Local Vault dev (two-step):**

1. `stackgen-vault/docs/aws-bastion` — bastion + read-only target; note `bastion_role_arn`.
2. This scenario with `create_cfn_preview_iam_role = true` and `trusted_assumer_arns = [bastion_role_arn]`.
3. Re-apply bastion with `additional_target_role_arns = [cfn_preview_role_arn output]`.
4. Guild `aws_role_arn` = `cfn_preview_role_arn` output.

Future solution modules add their own target roles; only extend bastion `additional_target_role_arns` — no Vault repo changes per solution.

## Demo prompts

**Intent to Infrastructure**

> Generate an S3 bucket with versioning in us-east-1 and open a PR; preview against stack staging-data

**Drift Management**

> Run drift management for stacks with prefix staging- in us-east-1 and open a reconcile PR if drift found

**Contextual compliance**

> Preflight this intent against FedRAMP moderate: private RDS in us-east-1 with encryption at rest

**Governed deployment**

> Open a governed PR for validated template cloudformation/staging-vpc.yaml in staging

## Run

```bash
cd examples/scenarios/cfn-author
tofu init && tofu apply
```

Register skills from `recommended_skill_names` output in your Guild tenant before demoing.

## Reset

```bash
tofu destroy
```

If `create_cfn_preview_iam_role` was true, the preview IAM role is destroyed with the scenario. Re-remove its ARN from Vault bastion `additional_target_role_arns` if registered.
