# Repository → IaC example

For a **full platform stack** (foundation, policies, AWS IAM + Guild, StackGen MCP, SDLC, and repo → IaC in one root), use [**`examples/agentic-infrastructure`**](../agentic-infrastructure) instead.

Runnable root that installs:

- **`aios-foundation`** / **`aios-policies`**
- **`aios-integration-github`** — read the repository behind `github_repo_url`
- **Optional StackGen MCP** — one Vault `Other`/`mcp` secret + guild integration for Consumer SSE at `{stackgen_url}/api/mcp/user` (same pattern as `examples/agentic-infrastructure`)
- **`aios-agent-repo-to-iac`** — agent **`repository-iac-architect`** and workflows **`repository-to-iac`** and **`repo-scan-appstack-github-export`**

## Run workflow

- **`repository-to-iac`** — provide **`github_repo_url`** (HTTPS or `owner/repo`). GitHub discovery + StackGen MCP IaC generation.

- **`repo-scan-appstack-github-export`** — provide **`github_repo_url`** and **`export_github_repo`** (target repo for StackGen **Export**). Optional **`aws_region`**, **`stackgen_project_name`**. Scans the source repo, builds/wires an appStack with env aligned to AWS/region, produces a deployable artifact (action run), then exports IaC to the target GitHub repo via the product Export flow (see module runbooks).

```bash
cd examples/repo-to-iac
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu apply
```

See [`modules/aios-agent-repo-to-iac/README.md`](../../modules/aios-agent-repo-to-iac/README.md) for module details.
