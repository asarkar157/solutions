# AIOS Integration — Argo CD

Provisions an Argo CD Guild integration for GitOps application health and sync inspection.

## Catalog note

This module defaults to `type = argocd` and image `ghcr.io/appcd-dev/stackgen-guild-integration-argocd:main`. Verify your StackGen Guild catalog lists `argocd` before apply. If not registered, set `integration_type = "kubernetes"` and follow your platform team's Kubernetes integration pattern (builtins may differ).

## Usage

```hcl
module "argocd_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-argocd?ref=main"

  server_url  = "https://argocd.internal.example.com"
  auth_token  = var.argocd_token
}
```

Existing secret metadata: `server_url`, `auth_token` (or `username` / `password`).

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID bound to the integration |
