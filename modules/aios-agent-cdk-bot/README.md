# AWS CDK bot (`aios-agent-cdk-bot`)

Guild agent pack for **GitHub-driven AWS CDK** changes with a **zero-defect validate bar** before any draft PR:

lint, typecheck, `cdk synth`, cfn-lint, assertion-based unit tests, and cdk-nag must all **PASS**.

## Quick start

```hcl
module "cdk_bot" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-cdk-bot?ref=main"

  model_names      = module.foundation.model_names
  policy_ids       = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  github_token     = var.github_token   # or github_secret_id when PAT already in Vault
}
```

Scenario: [`examples/scenarios/cdk-bot`](../../examples/scenarios/cdk-bot).

## Workflow

`cdk-app-update`: **`clone`** → **`edit`** → **`validate`** (quality loop back to `edit`, create PR in validate stage).

**Live progress (default):** `enable_progress_issue_comment = true` posts one GitHub issue comment at intake start and **PATCH**es it at the end of each agent stage (Template P). Set `false` to keep the legacy end-of-run Template E comment only.

## Optional AWS validation

Default is **hermetic** (no AWS creds). Set `enable_aws_validation = true` and complete the Guild/Vault AWS wizard: bastion `roleArn` + workspace `externalId` in customer trust policy; `aws_role_arn` is the **customer** role.

**Rotating the customer role:** create a new IAM role with the **same** trust policy (same bastion + same workspace external ID), update `aws_role_arn` on the Vault secret or integration — do not change the external ID. See [stackgen-vault `docs/aws_credential_rotation.md`](https://github.com/appcd-dev/stackgen-vault/blob/main/docs/aws_credential_rotation.md).

Optional customer IAM: [`aios-cdk-validate-iam`](../aios-cdk-validate-iam).

## Testing

- [`docs/workflow-test-inputs.md`](docs/workflow-test-inputs.md) — webhook payloads and T1–T7 matrix
- `bash tests/workflow_structure_test.sh`
- `bash scripts/verify-cdk-bot-workflow-scripts.sh`
- Fixtures: `examples/fixtures/cdk-repos/`

**CI:** [`ci.yml`](../../.github/workflows/ci.yml) runs `verify-cdk-bot-workflow-scripts.sh` on every PR. [`cdk-bot-docker.yml`](../../.github/workflows/cdk-bot-docker.yml) smoke-builds on PRs; on **push to `main`** it builds **linux/amd64 + linux/arm64**, pushes to **`ghcr.io/appcd-dev/solutions-cdk-bot-runner`**, and tags **`main`** plus **`script_pack_version`** (from `main.tf`).

Pull the CI image instead of building on the apply host:

```hcl
build_runner_image             = false
runner_docker_image_repository = "ghcr.io/appcd-dev/solutions-cdk-bot-runner"
runner_docker_image_tag        = "" # defaults to script_pack_version
```

Then `docker pull ghcr.io/appcd-dev/solutions-cdk-bot-runner:<script_pack_version>` on the runner host before `remote_runner_cli_start_command_with_secrets`.

## Remote runner script pack (no Docker rebuild per script change)

When `create_remote_runner` is true, Terraform provisions **`cdk-bot-runner-script-pack-env`** (generic vault secret) and binds it on the remote runner via mothership sync. After script changes:

1. `tofu apply` (refreshes tarball + secret)
2. Restart aiden-runner (or wait for secrets sync interval)

Rebuild the Docker image only when Node/CDK toolchain or `docker/Dockerfile` changes (`build_runner_image`).

### Docker image vs `tofu apply` (coupling)

| Artifact | How it is produced | When you need it |
|----------|-------------------|------------------|
| **Script pack tarball** | `archive_file` + `sg_secret` at **every** `tofu apply` | After any change under `scripts/` — restart aiden-runner for mothership sync |
| **Runner Docker image** | `null_resource` **`docker build` on the apply host** when `build_runner_image = true`, or **CI → GHCR** (`ghcr.io/appcd-dev/solutions-cdk-bot-runner:<script_pack_version>`) when `build_runner_image = false` | Node/CDK toolchain or Dockerfile changes; tag defaults to `script_pack_version` |

CI builds and pushes **multi-arch** (`linux/amd64`, `linux/arm64`) on every merge to `main` that touches this module. PRs run a single-arch smoke build only (no push).

To decouple apply from local `docker build`, set `build_runner_image = false` and pull the GHCR tag above on the runner host.

## Outputs

`agent_names`, `workflow_name`, `webhook_ingress_payload_url`, `remote_runner_name`, `remote_runner_token`, `runner_docker_image`, `runner_github_secret_id`, `runner_script_pack_env_secret_id`, optional `aws_integration_name`.
