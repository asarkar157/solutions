# AIOS Integration — Confluence

Provisions a Confluence knowledge-base integration for operational runbooks and postmortem templates.

## Usage

```hcl
module "confluence_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-confluence?ref=main"

  base_url  = "https://yourorg.atlassian.net/wiki"
  email     = var.confluence_email
  api_token = var.confluence_api_token
}
```

Or bind an existing vault secret:

```hcl
module "confluence_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-confluence?ref=main"

  existing_secret_id = var.confluence_secret_id
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID bound to the integration |
