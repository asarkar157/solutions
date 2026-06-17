# AIOS Integration — GitHub

Provisions a GitHub SCM integration for repository operations, PRs, and code analysis.

## Usage

```hcl
module "github_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-github"

  github_token = var.github_token
}
```

## Token security model

The GitHub PAT is **not** placed in container-wide environment variables. Guild mounts vault JSON into the sidecar; `mcp-shell` loads it into an in-memory `SecretStore` and injects `GH_TOKEN` **only** into subprocesses for approved CLIs (`gh`, `curl`) when `MCP_SHELL_SECRET_CLIS=gh,curl` is set.

- `env`, `printenv`, and similar enumeration commands remain blocked for agents.
- Per-request OAuth tokens (3-legged) are overlaid on the same scoped path via `MCP_SHELL_OAUTH_ENV=GH_TOKEN`.
- `github_test_connection` runs an identity probe (`gh api user`) when the sidecar image supports it — not merely `gh version`.

This module sets `MCP_SHELL_SECRET_CLIS = "gh,curl"` in Terraform for tighter subprocess scoping. Integrations without that env still receive mapped vault secrets in all MCP subprocesses when only `MCP_SECRET_MAP` is set.

## Troubleshooting

### `gh auth login` / "populate GH_TOKEN" despite Connection OK

**Symptom:** `github_test_connection` passes, but `github_execute_command` with `gh api user` fails with auth errors.

**Cause:** `MCP_SHELL_SECRET_CLIS` is missing on the integration env. Without it, the vault PAT stays in `SecretStore` but is never injected into `gh` or `curl` subprocesses. A startup probe of `gh version` alone does not require a token.

**Fix:**

1. In Guild → Settings → Integrations → your GitHub integration, add env:
   - `MCP_SHELL_SECRET_CLIS` = `gh,curl`
2. Confirm the vault secret metadata is `{ "token": "<valid PAT>" }` with scopes `repo` and `read:org`.
3. Recycle the sidecar (remove the `aios-integration-*` container or change env so Guild launches a new one).
4. Verify: `github_execute_command` → `gh api user -q .login` returns your GitHub login.

If `curl` still returns `401 Bad credentials` after fixing injection, rotate the PAT — the token may be expired or revoked.

### Existing integrations before image rebuild

Rebuild or pull a GitHub integration image that sets `MCP_SHELL_SECRET_CLIS=gh,curl`, **or** rely on Guild injecting mapped secrets into all MCP subprocesses when `MCP_SECRET_MAP` is set and `MCP_SHELL_SECRET_CLIS` is omitted (post-#637 gcx default removed).

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID |
