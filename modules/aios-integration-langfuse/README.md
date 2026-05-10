# AIOS Integration — Langfuse

Provisions a Langfuse LLM observability integration with API credentials stored in Vault.

## Usage

```hcl
module "langfuse_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-langfuse"

  langfuse_public_key = var.langfuse_public_key
  langfuse_secret_key = var.langfuse_secret_key
  langfuse_host       = "https://cloud.langfuse.com"
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `integration_id` | Server-assigned Guild integration ID |
| `secret_id` | Vault secret ID |
