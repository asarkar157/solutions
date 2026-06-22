# Scenario: `sre-boost`

## Pitch (read this on the call)

> "You already have an SRE agent in Guild. In one apply we register **new** GitHub and AWS connections, attach an **on-prem remote runner**, and wire them onto your existing agent — no new models, no new agent."

## What this scenario wires

- `aios-integration-github` — new GitHub MCP from `github_token`
- `aios-integration-aws` — new AWS MCP from `aws_role_arn`
- `aios-remote-runner` — aiden-runner + vault secret sync from those integrations
- `sg_agent` — **adopts** your existing agent by name; preserves persona and `model_names`; merges integrations + `remote_runners`

**Does not** call `aios-foundation` (no new LLM models) and **does not** create a new agent. **Does not** reuse existing tenant integrations — supply fresh `github_token` and an **allowlisted** `aws_role_arn`.

## Prerequisites

- An agent already registered in Guild (for example `aws-sre` from **`aws-sre-demo`**)
- At least one model already registered on that agent (from foundation or another root)
- GitHub PAT for the new GitHub integration
- AWS customer role ARN **already on the StackGen bastion allowlist** (see below)

### AWS IAM (assume role)

StackGen’s bastion (in the StackGen AWS account) assumes **your** customer role. You only change IAM in **your** account:

1. Fetch workspace values: `data.sg_vault_aws_config` or Guild **Add integration → AWS → Step 1** (`trust_policy`, `external_id`, `bastion_role_arn`).
2. Pass a customer `aws_role_arn` that StackGen has **already** registered on the bastion allowlist.
3. In your account, set the role trust policy to `trust_policy` from step 1 (`Principal` = bastion ARN, `sts:ExternalId`, `sts:TagSession`).

**Do not** create or edit IAM in the bastion account. New customer roles are not usable until StackGen ops adds them to the bastion allowlist — use an existing allowlisted role (e.g. `VaultTestTargetRole` in dev) or request allowlisting.

Optional: create/update the customer role only via [`modules/aios-aws-integration-iam`](../../../modules/aios-aws-integration-iam) in **your** account, then get the ARN allowlisted before `tofu apply`.

```hcl
aws_role_arn = "arn:aws:iam::ACCOUNT:role/your-allowlisted-role"
aws_region   = "us-east-1"
```

If Vault returns `ASSUME_ROLE_TRUST_DENIED`, fix customer trust policy first; if trust is correct, the role is not on the bastion allowlist yet (StackGen-side — not something you fix in your Terraform).

## Run

```bash
export AGENT_NAME=aws-sre
export GITHUB_TOKEN=ghp_...
export AWS_ROLE_ARN=arn:aws:iam::...
make demo SCENARIO=sre-boost
```

Or from this folder:

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars     # agent_name, github_token, aws_role_arn
tofu init
tofu import sg_agent.sre_boost <agent_name>
tofu apply
```

After apply, start the remote runner and confirm it shows **online** in Guild:

```bash
# Helm (Kubernetes)
tofu output -raw remote_runner_helm_install_command

# Docker
tofu output -raw remote_runner_docker_run_command

# Both in one block
tofu output -raw remote_runner_start_commands
```

## Talk track (~5 minutes)

1. **Show integrations** — fresh GitHub + AWS registered at tenant level from credentials you supply on the call.
2. **Show the runner** — outbound-only to mothership; secrets synced from Vault (no PAT in the runner image).
3. **Open the agent** — same name as before; new integrations + `remote_runners` on the detail page; models unchanged.
4. **Prompt** — unhealthy EC2 + "what shipped recently on GitHub?" Let the agent use AWS MCP, GitHub MCP, then runner shell if needed.

## Reset

```bash
make demo-reset SCENARIO=sre-boost
```

`destroy` removes the integrations and runner this root created and may revert agent fields this root manages — review plan before destroy on shared agents.
