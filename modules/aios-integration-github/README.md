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

Guild mounts vault JSON into the sidecar; `mcp-shell` loads it at startup and exports `GH_TOKEN` (via `MCP_SECRET_MAP`) into the integration process environment. MCP `execute_command` subprocesses inherit that environment.

- `env`, `printenv`, and similar enumeration commands remain blocked for agents in `execute_command`.
- Per-request OAuth tokens (3-legged) are overlaid on subprocess env via `MCP_SHELL_OAUTH_ENV=GH_TOKEN`.
- `github_test_connection` runs an identity probe (`gh api user`) when the sidecar image sets `MCP_SHELL_AUTH_PROBE_CMD` — not merely `gh version`.

## Troubleshooting

### `gh auth login` / "populate GH_TOKEN" despite Connection OK

**Symptom:** `github_test_connection` passes, but `github_execute_command` with `gh api user` fails with auth errors.

**Cause:** Vault PAT was not loaded or mapped. Common cases: missing or empty `token` in vault metadata, sidecar started before secrets were mounted, or stale container after token rotation.

**Fix:**

1. Confirm the vault secret metadata is `{ "token": "<valid PAT>" }` with scopes `repo` and `read:org`.
2. Recycle the sidecar (remove the `aios-integration-*` container or change env so Guild launches a new one).
3. Verify: `github_execute_command` → `gh api user -q .login` returns your GitHub login.

If `curl` still returns `401 Bad credentials` after fixing injection, rotate the PAT — the token may be expired or revoked.

### OAuth vs vault PAT

When a request includes a Bearer token, it replaces `GH_TOKEN` for that subprocess only. Vault PAT remains the fallback when no OAuth token is present.

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID |
