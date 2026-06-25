# Example: Jira → SRE Copilot (end-to-end)

Wires **Jira** into the **StackGen SRE Copilot** app the way it is meant to be done in
production, and documents how the integration was verified in depth.

It composes two library modules:

| Step | Module | Resource | Purpose |
|------|--------|----------|---------|
| 1 | [`aios-integration-jira`](../../modules/aios-integration-jira/) | `sg_secret` + `sg_guild_integration` | Stores Jira credentials in Vault, registers the `jira` integration (sidecar `ghcr.io/appcd-dev/stackgen-guild-integration-jira:main`), and projects `ATLASSIAN_*` env onto the sidecar so tool calls actually authenticate (see the module's *Known issue*). |
| 2 | [`aios-sre-app-bindings`](../../modules/aios-sre-app-bindings/) | `sg_app` | Adds the Jira integration name to the **installed SRE app** (`PUT /api/v1/apps/sre`) so the SRE investigator can call Jira tools. |

## Why step 2 matters (the gotcha)

Adding Jira under **Settings → Integrations** only creates a **workspace/project**
integration (`sg_guild_integration`). The **SRE app install is a separate object**: it
keeps its own list of bound integration names. Until that list contains your Jira
integration, the SRE investigator reports *"Required tool Jira/API access is not
available"* even though the workspace integration is healthy.

`sg_app.integrations` is the join. This example sets it via `aios-sre-app-bindings`
with `merge_existing_app_integrations = true`, so the apply **adds** Jira without
dropping integrations that SRE app onboarding already bound (e.g. Datadog).

```
Settings → Integrations          SRE app install (sg_app)
  sg_guild_integration "jira" ──▶ integrations = [ ...existing, "jira-integration" ]
                                            │
                                            ▼
                                  stackgen-sre-investigator can call Jira tools
```

This is the same path a user follows in the UI: connect Jira, then open the SRE app's
**Configure → Integrations** and toggle Jira on. The module makes that binding
reproducible in Terraform.

## Prerequisites

- Provider `sg` **>= 0.1.27** (`sg_app`). Pulled automatically from `releases.stackgen.com`.
- **stackgen-sre-app already installed** in the target Guild org (catalog slug `sre`).
- A StackGen PAT (`stackgen_token`) and, optionally, a `stackgen_project_id`.
- Jira Cloud base URL, account email, and an API token
  ([create one here](https://id.atlassian.com/manage-profile/security/api-tokens)).

## Usage

```hcl
# terraform.tfvars
stackgen_url        = "https://main.dev.stackgen.com"
stackgen_token      = "sg_pat_xxx"
stackgen_project_id = "your-project-id"

jira_base_url  = "https://yourorg.atlassian.net"
jira_email     = "you@yourorg.com"
jira_api_token = "<jira-api-token>" # keep out of VCS; prefer TF_VAR_jira_api_token
```

```bash
export TF_VAR_jira_api_token="<jira-api-token>"   # avoid committing the token
tofu init
tofu plan
tofu apply
```

Already onboarded the SRE app with Datadog? Leave `bind_to_sre_app = true`
(default) — the union keeps Datadog and just adds Jira. If Terraform did not create
the binding, import the install first:

```bash
tofu import 'module.sre_app_bindings[0].sg_app.sre' sre
```

## Local verification (how this repo "tests" a module)

This repo's gate is `tofu fmt` + `tofu validate` over every root under `modules/` and
`examples/` (see [`README.md`](../../README.md) → *Local verification* and
[`scripts/terraform-validate-all.sh`](../../scripts/terraform-validate-all.sh)). The
StackGen provider downloads from `releases.stackgen.com` **without** registry auth, so
validation runs offline-of-credentials:

```bash
# from repo root
make fmt-check        # tofu fmt -check -recursive
make validate         # tofu init -backend=false && tofu validate per root

# or just this example / the module
cd examples/jira-sre-app   && tofu init -backend=false && tofu validate
cd modules/aios-integration-jira && tofu init -backend=false && tofu validate
```

Verified results (OpenTofu 1.12.3, provider `stackgen` v0.1.30):

- `modules/aios-integration-jira` — `tofu validate` → **Success! The configuration is valid.**
- `examples/jira-sre-app` — `tofu validate` → **Success! The configuration is valid.**
- `tofu fmt -check` — clean (no diffs).

## Verify end-to-end on the dev tenant

`tofu validate` only proves the config is well-formed. To confirm Jira works **with Guild
and the agent runtime** on the dev tenant (`stackgen_url = https://main.dev.stackgen.com`),
apply this root and then exercise it the way the product does:

1. **Apply** — `tofu apply` stores the Vault secret (`base_url/email/api_token`), creates the
   `jira` integration with the `ATLASSIAN_*` env the sidecar needs, and binds it onto the SRE
   app. Guild launches the sidecar and reports `Integration confirmed, discovered 5 tool(s)`
   (`jira_get/post/put/patch/delete`).
2. **Open the SRE app** → *Configure → Integrations* and confirm **Jira** shows connected
   (it appears because `sg_app.integrations` now includes it).
3. **Ask through the SRE app chat / agent** — e.g. *"List the Jira projects I can access"* or
   *"List open issues in project SUP"*. The agent calls the Jira sidecar tools and returns
   live data (your tenant's project keys/names and recent issues).

**Why the module sets `env` (do not remove it):** with only the Vault secret, the integration
**test/handshake still passes** (it reports `discovered 5 tool(s)`), but every real tool call
fails with `Authentication credentials are missing` and the sidecar logs
`set ATLASSIAN_SITE_NAME, ATLASSIAN_USER_EMAIL, ATLASSIAN_API_TOKEN`. The module projects the
Vault credentials onto that env so the agent path authenticates. The test endpoint does **not**
catch this — only an actual tool call does. See the module's *Known issue*.

Keep ticket-writing behind an approval policy in production (see
[`modules/aios-policies`](../../modules/aios-policies/)) so Aiden proposes ticket
creates/updates for review before writing to Jira.

## Variables

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `stackgen_url` | yes | — | Guild tenant base URL |
| `stackgen_token` | yes | — | StackGen PAT (sensitive) |
| `stackgen_project_id` | no | `""` | Project/org scope |
| `jira_base_url` | cond. | `""` | Jira instance URL (required unless `existing_jira_secret_id`) |
| `jira_email` | cond. | `""` | Atlassian email (required unless `existing_jira_secret_id`) |
| `jira_api_token` | cond. | `""` | Jira API token (sensitive; required unless `existing_jira_secret_id`) |
| `existing_jira_secret_id` | cond. | `""` | Reuse an existing Vault secret instead of creating one |
| `integration_name` | no | `jira-integration` | Guild integration name |
| `integration_scope` | no | `PROJECT` | `PROJECT` or `WORKSPACE` |
| `bind_to_sre_app` | no | `true` | Bind onto the installed SRE app via `sg_app` |
| `sre_app_name` | no | `sre` | SRE app catalog slug |

## Outputs

| Name | Description |
|------|-------------|
| `jira_integration_name` | Name of the created Jira integration |
| `sre_app_integration_names` | Integrations bound to the SRE app after apply |
| `sre_app_configured` | Whether the SRE app install is configured |

## Cleanup

`tofu destroy` removes the Jira integration and clears it from the SRE app binding set
(it does not uninstall the SRE app or delete Jira data).
