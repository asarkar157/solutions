# =============================================================================
# AIOS Foundation Module
# =============================================================================
# Provisions LLM secrets, model providers, and named model instances.
# This is the base module that all other AIOS modules depend on.

# =============================================================================
# Provider Configuration
# =============================================================================

provider "sg" {
  host      = var.guild_url
  api_token = var.guild_token
  insecure  = var.guild_insecure
  org_id    = var.org_id
}

# =============================================================================
# LLM Vault Secrets
# =============================================================================

resource "sg_secret" "openai" {
  count       = var.llm_api_keys.openai != "" ? 1 : 0
  name        = "openai-vault"
  description = "OpenAI API Key"
  category    = "LLM"
  subcategory = "openai"
  metadata = {
    OPENAI_API_KEY = var.llm_api_keys.openai
  }
}

resource "sg_secret" "anthropic" {
  count       = var.llm_api_keys.anthropic != "" ? 1 : 0
  name        = "anthropic-vault"
  description = "Anthropic API Key"
  category    = "LLM"
  subcategory = "anthropic"
  metadata = {
    ANTHROPIC_API_KEY = var.llm_api_keys.anthropic
  }
}

resource "sg_secret" "gemini" {
  count       = var.llm_api_keys.gemini != "" ? 1 : 0
  name        = "gemini-vault"
  description = "Gemini API Key"
  category    = "LLM"
  subcategory = "gemini"
  metadata = {
    GEMINI_API_KEY = var.llm_api_keys.gemini
  }
}

# =============================================================================
# Model Providers
# =============================================================================

resource "sg_guild_model_provider" "openai" {
  count           = var.llm_api_keys.openai != "" ? 1 : 0
  name            = "openai"
  provider_type   = "openai"
  token_reference = sg_secret.openai[0].name
}

resource "sg_guild_model_provider" "anthropic" {
  count           = var.llm_api_keys.anthropic != "" ? 1 : 0
  name            = "anthropic"
  provider_type   = "anthropic"
  token_reference = sg_secret.anthropic[0].name
}

resource "sg_guild_model_provider" "gemini" {
  count           = var.llm_api_keys.gemini != "" ? 1 : 0
  name            = "gemini"
  provider_type   = "gemini"
  token_reference = sg_secret.gemini[0].name
}

# =============================================================================
# Named Model Instances
# =============================================================================

resource "sg_guild_model" "models" {
  for_each = var.models

  name          = each.key == "gpt4o" ? "gpt-4o" : (each.key == "claude_sonnet" ? "claude-sonnet" : (each.key == "gemini_flash" ? "gemini-flash" : each.key))
  provider_name = each.value.provider_name
  model_id      = each.value.model_id
  good_for_task = each.value.good_for_task
}
