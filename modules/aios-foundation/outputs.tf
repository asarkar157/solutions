output "model_names" {
  description = "Map of logical model names to their Guild-registered names"
  value = {
    for k, v in sg_guild_model.models : k => v.name
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
