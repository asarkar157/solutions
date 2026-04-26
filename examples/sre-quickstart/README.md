# SRE Quickstart Example

Minimal SRE setup with incident response agents. ~20 lines of consumer HCL.

## Usage

```hcl
module "foundation" {
  source = "github.com/stackgen-demo/solutions//modules/aios-foundation"

  guild_url   = "https://guild.example.com"
  guild_token = var.guild_token
  llm_api_keys = {
    openai    = var.openai_key
    anthropic = var.anthropic_key
  }
}

module "policies" {
  source = "github.com/stackgen-demo/solutions//modules/aios-policies"
}

module "sre" {
  source = "github.com/stackgen-demo/solutions//modules/aios-agent-sre"

  model_names = module.foundation.model_names
  policy_ids  = module.policies.policy_ids
}
```
