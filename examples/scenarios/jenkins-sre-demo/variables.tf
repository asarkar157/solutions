variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant (no trailing slash). Example: https://main.dev.stackgen.com"
  type        = string
}

variable "stackgen_token" {
  description = "StackGen personal access token. Generate one from the Guild UI under your profile."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "Optional StackGen project / org ID. Leave empty unless your tenant requires explicit project scope."
  type        = string
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key. At least one of openai / anthropic / gemini must be set so the foundation module registers a model."
  type        = string
  sensitive   = true
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key."
  type        = string
  sensitive   = true
  default     = ""
}

variable "gemini_api_key" {
  description = "Gemini API key."
  type        = string
  sensitive   = true
  default     = ""
}

variable "jenkins_integration_name" {
  description = "Unique name for the Jenkins integration."
  type        = string
  default     = "jenkins-integration"
}

variable "jenkins_base_url" {
  description = "Root URL of your Jenkins controller (e.g. https://jenkins.example.com). Requires the MCP Server plugin to be installed and enabled."
  type        = string
  default     = ""
}

variable "jenkins_username" {
  description = "Username of the Jenkins user to authenticate as."
  type        = string
  default     = ""
}

variable "jenkins_token" {
  description = "API token or password for the Jenkins user."
  type        = string
  sensitive   = true
  default     = ""
}

variable "jenkins_mcp_url" {
  description = "Optional override for the Jenkins MCP streamable HTTP URL. Defaults to {jenkins_base_url}/mcp-server/mcp."
  type        = string
  default     = ""
}

variable "existing_jenkins_secret_id" {
  description = "Optional ID of an existing sg_secret containing Jenkins credentials."
  type        = string
  default     = ""
}

variable "integration_scope" {
  description = "Guild integration scope for Jenkins (e.g. PROJECT or tenant/org equivalent)."
  type        = string
  default     = "PROJECT"
}

variable "slack_bot_token" {
  description = "Slack Bot Token. Optional: leave empty to skip the Slack integration in this scenario (the agent still runs in Guild chat)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "agent_name" {
  description = "Name of the Jenkins SRE agent."
  type        = string
  default     = "jenkins-sre-agent"
}
