# The model_names output always includes all 3 keys. If a provider is not
# configured, its value is an empty string. This satisfies the downstream
# object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
# type constraint without erroring.

output "model_names" {
  description = "Map of logical model names to their Guild-registered names. Empty string if model not configured."
  value = {
    gpt4o         = length(sg_guild_model.gpt4o) > 0 ? sg_guild_model.gpt4o[0].name : ""
    claude_sonnet = length(sg_guild_model.claude_sonnet) > 0 ? sg_guild_model.claude_sonnet[0].name : ""
    gemini_flash  = length(sg_guild_model.gemini_flash) > 0 ? sg_guild_model.gemini_flash[0].name : ""
  }
}

output "model_provider_names" {
  description = "Map of provider names"
  value = merge(
    length(sg_guild_model_provider.openai) > 0 ? { openai = sg_guild_model_provider.openai[0].name } : {},
    length(sg_guild_model_provider.anthropic) > 0 ? { anthropic = sg_guild_model_provider.anthropic[0].name } : {},
    length(sg_guild_model_provider.gemini) > 0 ? { gemini = sg_guild_model_provider.gemini[0].name } : {},
  )
}

output "secret_names" {
  description = "Map of LLM vault secret names"
  value = merge(
    length(sg_secret.openai) > 0 ? { openai = sg_secret.openai[0].name } : {},
    length(sg_secret.anthropic) > 0 ? { anthropic = sg_secret.anthropic[0].name } : {},
    length(sg_secret.gemini) > 0 ? { gemini = sg_secret.gemini[0].name } : {},
  )
}
