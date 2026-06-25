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
  description = "API token or password for the Jenkins user (mutually exclusive with existing_secret_id)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "jenkins_mcp_url" {
  description = "Optional override for the Jenkins MCP streamable HTTP URL. Defaults to {jenkins_base_url}/mcp-server/mcp."
  type        = string
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional ID of an existing sg_secret containing Jenkins credentials. Must contain keys: jenkins_base_url, jenkins_username, and jenkins_token."
  type        = string
  default     = ""
}

variable "integration_name" {
  description = "Unique name for the Jenkins integration."
  type        = string
  default     = "jenkins-integration"
}

variable "description" {
  description = "Human-friendly description of the integration."
  type        = string
  default     = "Jenkins CI/CD integration for triggering builds and checking job status"
}

variable "scope" {
  description = "Scope level of the integration (PROJECT or tenant/org equivalent)."
  type        = string
  default     = "PROJECT"
}

variable "enabled" {
  description = "Whether the integration is active."
  type        = bool
  default     = true
}
