# AIOS Integration — Jira

Provisions a Jira integration for issue triage, sprint context, and ticket updates.

## Usage

Create a Vault secret from Terraform variables:

```hcl
module "jira_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-jira?ref=main"

  base_url  = "https://yourorg.atlassian.net"
  email     = var.jira_email
  api_token = var.jira_api_token
}
```

Or bind an existing Vault secret that already contains `base_url`, `email`, and `api_token` metadata:

```hcl
module "jira_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-jira?ref=main"

  existing_secret_id = var.jira_secret_id

  # When you only pass existing_secret_id the module cannot read the raw
  # credentials, so supply the values the sidecar needs directly:
  base_url = "https://yourorg.atlassian.net" # used only to derive ATLASSIAN_SITE_NAME
  email    = var.jira_email
  # api_token is already in the secret; pass it again here only if you want the
  # module to project ATLASSIAN_API_TOKEN for you (otherwise set env yourself).
}
```

## Known issue — sidecar credentials (why this module sets `env`)

The Jira sidecar image (`ghcr.io/appcd-dev/stackgen-guild-integration-jira`) authenticates
from **`ATLASSIAN_SITE_NAME` / `ATLASSIAN_USER_EMAIL` / `ATLASSIAN_API_TOKEN` environment
variables**. Vault stores Jira credentials under `base_url` / `email` / `api_token`
(enforced metadata keys), and Guild delivers those to the sidecar as
`/run/secrets/env.json` request headers — which the sidecar's credential resolver does
**not** read. The net effect:

- `sg_guild_integration` create + the integration **test/validate pass** (they only confirm
  the MCP sidecar handshake and its 5 tools), but
- every actual Jira tool call fails with `Authentication credentials are missing`.

This is the exact symptom you hit when adding Jira through **Settings → Integrations**.

To make Jira authenticate, this module **projects the same credentials onto the env the
sidecar actually consumes**:

```hcl
env = {
  ATLASSIAN_SITE_NAME  = "<site>"   # sub-domain of base_url (https://<site>.atlassian.net)
  ATLASSIAN_USER_EMAIL = var.email
  ATLASSIAN_API_TOKEN  = var.api_token
}
```

`ATLASSIAN_SITE_NAME` is derived from `base_url`; override it with `atlassian_site_name`
for custom domains. The long-term fix belongs in the sidecar image (read the vault keys) —
track it before relying on the Vault-only path.

## Bind it to the SRE Copilot app

Creating this integration only registers a **workspace/project** integration. The
**SRE app install keeps its own integration list**, so the SRE investigator cannot call
Jira until the app's `sg_app.integrations` includes this integration name. Pass
`module.jira_integration.integration_name` to [`aios-sre-app-bindings`](../aios-sre-app-bindings/):

```hcl
module "sre_app_bindings" {
  source = "github.com/appcd-dev/solutions//modules/aios-sre-app-bindings?ref=main"

  merge_existing_app_integrations = true
  integration_names               = [module.jira_integration.integration_name]
}
```

A full, validated end-to-end root lives in [`examples/jira-sre-app`](../../examples/jira-sre-app/).

## Aiden 2.0 Use Case

Attach `module.jira_integration.integration_name` to an SRE or ticket-resolution agent so Aiden can use Jira during incident work:

- Read Jira issues linked to an alert, service, sprint, or project.
- Create a follow-up ticket from an investigation summary.
- Update an existing ticket with RCA, evidence links, or mitigation status after the operator reviews the proposed change.

Keep destructive operations behind approval policies in production so Aiden can draft or propose ticket updates before writing to Jira.

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent / SRE-app-binding modules |
| `secret_id` | Vault secret ID bound to the integration (sensitive) |
| `atlassian_site_name` | Site name projected onto `ATLASSIAN_SITE_NAME` |
| `sidecar_env_keys` | Env var names set on the sidecar (values omitted) |

## Verify end-to-end on a StackGen tenant

After `tofu apply` against your tenant (`stackgen_url` / `stackgen_token`, e.g.
`https://main.dev.stackgen.com`):

1. Guild creates the Vault secret + `jira` integration, launches the sidecar, and discovers
   the 5 Jira tools (`jira_get/post/put/patch/delete`).
2. Attach the integration to an agent (or bind it onto the SRE app — see
   [`examples/jira-sre-app`](../../examples/jira-sre-app/)).
3. Ask the agent to list Jira projects/issues. With only the Vault secret the tool call
   returns `Authentication credentials are missing`; with the `ATLASSIAN_*` env projection
   above, the agent returns **live** data (your tenant's project keys/names and recent issues).
