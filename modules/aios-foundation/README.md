# AIOS Foundation

Provisions LLM vault secrets, model providers, and named model instances. The root module must configure the `sg` provider (`stackgen_url` / `stackgen_token`). This is the base module that every other AIOS module depends on.

## Usage

```hcl
module "foundation" {
  source = "github.com/appcd-dev/solutions//modules/aios-foundation"

  stackgen_url   = "https://main.dev.stackgen.com"
  stackgen_token = var.stackgen_token

  llm_api_keys = {
    openai    = var.openai_api_key
    anthropic = var.anthropic_api_key
    gemini    = var.gemini_api_key
  }
}
```

## What It Creates

| Resource Type | Count | Description |
|---|---|---|
| `sg_secret` | 3 | Vault secrets for OpenAI, Anthropic, Gemini API keys |
| `sg_guild_model_provider` | 3 | LLM provider registrations |
| `sg_guild_model` | 3 | Named model instances (gpt-4o, claude-sonnet, gemini-flash) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `stackgen_url` | Base URL of the StackGen platform | `string` | — | yes |
| `stackgen_token` | Bearer token for API authentication | `string` | `""` | no |
| `stackgen_insecure` | Allow plaintext HTTP (dev only) | `bool` | `false` | no |
| `org_id` | Organization ID | `string` | `""` | no |
| `llm_api_keys` | LLM provider API keys | `object` | `{}` | no |
| `name_prefix` | Prefix for resource names | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| `model_names` | Map of model name references (`gpt4o`, `claude_sonnet`, `gemini_flash`) |
| `model_provider_names` | Map of provider name references |
| `secret_names` | Map of vault secret names |
