# AIOS Foundation

Provisions the StackGen provider configuration, LLM vault secrets, model providers, and named model instances. This is the base module that every other AIOS module depends on.

## Usage

```hcl
module "foundation" {
  source = "github.com/stackgen-demo/solutions//modules/aios-foundation"

  guild_url   = "https://guild.example.com"
  guild_token = var.guild_token

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
| `guild_url` | Base URL of the StackGen platform | `string` | — | yes |
| `guild_token` | Bearer token for API authentication | `string` | `""` | no |
| `guild_insecure` | Allow plaintext HTTP (dev only) | `bool` | `false` | no |
| `org_id` | Organization ID | `string` | `""` | no |
| `llm_api_keys` | LLM provider API keys | `object` | `{}` | no |
| `models` | Model configuration overrides | `map(object)` | see defaults | no |

## Outputs

| Name | Description |
|------|-------------|
| `model_names` | Map of model name references (`gpt4o`, `claude_sonnet`, `gemini_flash`) |
| `model_provider_names` | Map of provider name references |
| `secret_names` | Map of vault secret names |
