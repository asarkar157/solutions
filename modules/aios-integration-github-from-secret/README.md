# aios-integration-github-from-secret

Tiny **secret-only** module: takes a raw GitHub PAT and writes a single
`sg_secret` shaped `Provider/github` with metadata keys `GIT_TOKEN`,
`GIT_HOST`, `GIT_USERNAME`. **No Guild integration container** is created
here.

## Why this exists

The Guild Ubuntu integration image's `pre_launch.sh` surfaces secrets
matching `category = "Provider"`, `subcategory = "github"` as `GIT_*` env
vars in every shell the agent spawns. That means `git clone`, `git push`,
and `gh auth status` against private repos Just Work — no explicit token
capture step.

The canonical `SCM/github` secret shape used by
[`aios-integration-github`](../aios-integration-github) is **not** unpacked
by the current Ubuntu image (only the AWS unpacker is wired). Until the
upstream image PR (`pre_launch.sh` SCM/github unpacker) lands, agent modules
need this sibling secret to get the same env-mounted-token UX they'd
otherwise get for AWS.

## Usage

```hcl
# 1. Wrap a raw PAT into the Provider/github sibling secret.
module "github_pat" {
  source  = "github.com/appcd-dev/solutions//modules/aios-integration-github-from-secret?ref=main"
  name    = "tenant-github-pat"
  github_token = var.github_token   # only place the PAT exists in TF
}

# 2. Pass the resulting secret ID into self-contained agent modules.
module "scenario_author" {
  source = "github.com/appcd-dev/solutions//modules/aios-agent-scenario-author?ref=main"

  model_names      = [...]
  policy_ids       = { dangerous_ops = sg_policy.dangerous_ops.id }
  github_secret_id = module.github_pat.secret_id

  repository_full_name = "appcd-dev/solutions"
  agent_budget         = 10
}
```

The agent module internally:
- Creates a private GitHub Guild integration (uses the secret for `gh api`).
- Creates a private Ubuntu Guild integration with `secret_ref_ids =
  [module.github_pat.secret_id]` so `printenv GIT_TOKEN` returns a valid PAT
  inside the sandbox.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | string | `github-pat` | Logical name; resulting secret is `<name>-provider-github-vault`. |
| `github_token` | string (sensitive) | _required_ | The raw PAT. |
| `git_host` | string | `github.com` | Surfaced as `GIT_HOST` env. |
| `git_username` | string | `x-access-token` | Surfaced as `GIT_USERNAME` env. Works for GitHub PATs. |
| `description` | string | shown above | Vault UI description. |

## Outputs

| Name | Description |
|------|-------------|
| `secret_id` | The `sg_secret` ID. Pass to agent modules as `github_secret_id`. (sensitive) |
| `secret_name` | The `sg_secret` name. |

## Long-term path

Once the Guild Ubuntu image's `pre_launch.sh` learns to unpack
`SCM/github` shaped secrets, this module becomes unnecessary — consumers
can pass `aios-integration-github`'s SCM/github secret_id directly to
both the GitHub integration container *and* the Ubuntu sandbox.
