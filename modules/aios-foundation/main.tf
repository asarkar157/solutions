# =============================================================================
# AIOS Foundation Module
# =============================================================================
# Provisions LLM secrets, model providers, and named model instances.
# This is the base module that all other AIOS modules depend on.
#
# NOTE: This module does NOT define a provider block. The consumer must
# configure the "sg" provider in their root module:
#
#   provider "sg" {
#     stackgen_url   = var.stackgen_url
#     stackgen_token = var.stackgen_token
#   }

# =============================================================================
# LLM Vault Secrets
# =============================================================================

resource "sg_secret" "openai" {
  count       = var.llm_api_keys.openai != "" ? 1 : 0
  name        = "${var.name_prefix}openai-vault"
  description = "OpenAI API Key"
  category    = "LLM"
  subcategory = "openai"
  metadata = {
    OPENAI_API_KEY = var.llm_api_keys.openai
  }
}

resource "sg_secret" "anthropic" {
  count       = var.llm_api_keys.anthropic != "" ? 1 : 0
  name        = "${var.name_prefix}anthropic-vault"
  description = "Anthropic API Key"
  category    = "LLM"
  subcategory = "anthropic"
  metadata = {
    ANTHROPIC_API_KEY = var.llm_api_keys.anthropic
  }
}

resource "sg_secret" "gemini" {
  count       = var.llm_api_keys.gemini != "" ? 1 : 0
  name        = "${var.name_prefix}gemini-vault"
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

resource "sg_guild_model" "gpt4o" {
  count         = var.llm_api_keys.openai != "" ? 1 : 0
  name          = "gpt-4o"
  provider_name = sg_guild_model_provider.openai[0].name
  model_id      = "gpt-4o"
  good_for_task = "tool_calling"
}

resource "sg_guild_model" "claude_sonnet" {
  count         = var.llm_api_keys.anthropic != "" ? 1 : 0
  name          = "claude-sonnet"
  provider_name = sg_guild_model_provider.anthropic[0].name
  model_id      = "claude-sonnet-4-6"
  good_for_task = "planning"
}

resource "sg_guild_model" "gemini_flash" {
  count         = var.llm_api_keys.gemini != "" ? 1 : 0
  name          = "gemini-flash"
  provider_name = sg_guild_model_provider.gemini[0].name
  model_id      = "gemini-3-flash-preview"
  good_for_task = "efficiency"
}
