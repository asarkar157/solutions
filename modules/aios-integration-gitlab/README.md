# AIOS Integration — GitLab

Provisions a GitLab Guild integration (`type = gitlab`) with instance URL and API token stored in Vault.

## Usage

```hcl
module "gitlab_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-gitlab?ref=main"

  base_url      = "https://gitlab.example.com"
  private_token = var.gitlab_token
}
```

Or bind an existing vault secret (metadata keys: `base_url`, `private_token` or `api_token`):

```hcl
module "gitlab_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-gitlab?ref=main"

  existing_secret_id = var.gitlab_secret_id
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID bound to the integration |
