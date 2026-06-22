# `model_names` is the canonical input for every aios-agent-* module: a
# list of Guild-registered model names in stable, deterministic order
# (gpt54 → claude_sonnet → gemini_flash). Unconfigured providers are
# omitted (no empty strings). Agent modules pass it straight through to
# `sg_agent.model_names` after `compact()` so they no longer dictate
# which keys must exist.
#
# `model_names_by_provider` retains the original map shape for callers
# that need to hand-pick a specific provider (e.g. "always use gpt54
# here" for a quick local override).

output "model_names" {
  description = "Ordered list of Guild-registered model names. Stable order: gpt54, claude_sonnet, gemini_flash. Unconfigured providers are omitted. Wire directly to any aios-agent-* module's `model_names` input."
  value = compact([
    length(sg_guild_model.gpt54) > 0 ? sg_guild_model.gpt54[0].name : "",
    length(sg_guild_model.claude_sonnet) > 0 ? sg_guild_model.claude_sonnet[0].name : "",
    length(sg_guild_model.gemini_flash) > 0 ? sg_guild_model.gemini_flash[0].name : "",
  ])
}

output "model_names_by_provider" {
  description = "Map of provider key → Guild-registered model name. Empty string when the provider is not configured. Use when you need to hand-pick a specific model (e.g. `module.foundation.model_names_by_provider.gpt54`)."
  value = {
    gpt54         = length(sg_guild_model.gpt54) > 0 ? sg_guild_model.gpt54[0].name : ""
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
