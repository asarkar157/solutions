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

variable "stackgen_insecure" {
  description = "Allow plaintext HTTP to stackgen_url (local dev-edge on localhost:8088 only)."
  type        = bool
  default     = false
}

# ----- Grafana (required) ----------------------------------------------------
variable "grafana_server" {
  description = "Base URL of the Grafana server (https://...). Used by the Grafana MCP integration for read-only telemetry during investigation."
  type        = string
}

variable "grafana_token" {
  description = "Grafana service-account token paired with grafana_server."
  type        = string
  sensitive   = true
}

variable "tracked_service" {
  description = "Service name the demo tracks in Grafana alert labels. Used in the README monitor-scoping guidance and outputs."
  type        = string
  default     = "payments-api"
}

variable "tracked_env" {
  description = "Environment label the demo tracks in Grafana alert rules."
  type        = string
  default     = "demo"
}

variable "tracked_github_repo" {
  description = "GitHub repository full name (org/repo) that owns the tracked service. The investigator correlates Grafana alerts with recent commits and blame in this repo."
  type        = string
  default     = "stackgen-demo/order-service"
}

# ----- GitHub (required) -----------------------------------------------------
variable "github_token" {
  description = "GitHub personal access token (requires repo, read:org scopes). The investigator uses this to read repo context, correlate commits with the alert, and open the RCA fix PR."
  type        = string
  sensitive   = true
}

# ----- Slack (optional) ------------------------------------------------------
variable "slack_bot_token" {
  description = "Slack Bot Token. Optional: leave empty to skip the Slack integration (the agents still run in Guild chat)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "gateway_base_url" {
  description = "Public Omnichannel Gateway origin (no trailing slash), e.g. https://gateway.example.com. When set, outputs include gateway_slack_event_url for Slack App Event Subscriptions."
  type        = string
  default     = ""
}

variable "enable_sre_app_bindings" {
  description = "Bind Grafana/GitHub (and Slack when enabled) integrations to the installed stackgen-sre-app via sg_app. Set false if the SRE app is not yet installed in this org."
  type        = bool
  default     = true
}

variable "enable_grafana_alert_webhook" {
  description = "When true (and enable_sre_app_bindings is true), register a Grafana alert ingest webhook on the SRE app via sg_sre_alert_webhook. Requires provider sg >= 0.1.27."
  type        = bool
  default     = true
}

variable "grafana_alert_auto_investigate" {
  description = "When enable_grafana_alert_webhook is true, auto-start investigations on newly ingested Grafana alerts."
  type        = bool
  default     = false
}


variable "investigator_agent_name" {
  description = "SRE app investigator agent name (from stackgen-sre-app manifest). Attach remote runner after the app is installed."
  type        = string
  default     = "stackgen-sre-investigator"
}
