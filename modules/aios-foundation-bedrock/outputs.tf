output "model_names" {
  description = "List containing the Bedrock Claude Sonnet 4.6 model name when configured. Wire to aios-agent-* model_names (alone or concat with module.foundation.model_names)."
  value = compact([
    length(sg_guild_model.claude_sonnet_bedrock) > 0 ? sg_guild_model.claude_sonnet_bedrock[0].name : "",
  ])
}

output "model_names_by_provider" {
  description = "Map with bedrock key → registered model name (empty when not configured)."
  value = {
    bedrock = length(sg_guild_model.claude_sonnet_bedrock) > 0 ? sg_guild_model.claude_sonnet_bedrock[0].name : ""
  }
}

output "model_provider_names" {
  description = "Map of Bedrock provider name when configured."
  value = length(sg_guild_model_provider.bedrock) > 0 ? {
    bedrock = sg_guild_model_provider.bedrock[0].name
  } : {}
}

output "secret_names" {
  description = "Map of Bedrock vault secret names when static AWS keys are used."
  value = length(sg_secret.bedrock) > 0 ? {
    bedrock = sg_secret.bedrock[0].name
  } : {}
}

output "inference_profile_id" {
  description = "Resolved Bedrock model_id (cross-region inference profile) used for Claude Sonnet 4.6."
  value       = local.claude_sonnet_46_model_id
}

output "bedrock_enabled" {
  description = "True when bedrock_auth supplied IAM mode or static AWS keys."
  value       = local.bedrock_enabled
}
