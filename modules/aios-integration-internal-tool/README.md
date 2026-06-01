# aios-integration-internal-tool

**Internal Tooling** hook for PrivateSaaS: a generic REST API Guild integration (`type = restapi`) aimed at operator consoles, service catalogs, ownership matrices, and dependency graphs behind your VPC.

This is not a separate Guild builtin type; it uses the standard **`restapi`** integration with Vault metadata aligned to StackGen Vault’s REST API shape.

## Vault metadata

| Key | Required | Notes |
|-----|----------|-------|
| `base_url` | yes | API origin (no trailing path required) |
| `auth_header` | no | e.g. `Bearer <token>` — auto-set when `api_key` is provided |

## Usage

```hcl
module "internal_tool" {
  source = "../../modules/aios-integration-internal-tool"

  integration_name = "privatesaas-internal-console"
  base_url         = "https://console.internal.example.com/api/v1"
  api_key          = var.internal_console_token
}
```

Bind an existing secret instead:

```hcl
module "internal_tool" {
  source = "../../modules/aios-integration-internal-tool

  integration_name   = "privatesaas-internal-console"
  existing_secret_id = var.internal_tool_secret_id
}
```

## Guild catalog

Confirm `restapi` and image tag via `GET /api/v1/integrations/types`. Default image: `ghcr.io/appcd-dev/integration-restapi:latest`.

## Outputs

| Output | Description |
|--------|-------------|
| `integration_name` | Guild integration name for agent wiring |
| `secret_id` | Bound `sg_secret` ID |
