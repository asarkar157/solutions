variable "datadog_api_key" {
  description = "Datadog API key. Used when creating a new vault secret. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_app_key" {
  description = "Datadog application key paired with `datadog_api_key`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_site" {
  description = "Datadog site hostname (e.g. datadoghq.com, datadoghq.eu, us3.datadoghq.com)."
  type        = string
  default     = "datadoghq.com"
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with Datadog MCP credentials. Mutually exclusive with `datadog_api_key`."
  type        = string
  default     = ""
}

variable "integration_name" {
  description = "Guild integration resource name."
  type        = string
  default     = "datadog-integration"
}

variable "description" {
  type    = string
  default = "Datadog observability integration (official Datadog MCP server)."
}

variable "scope" {
  type    = string
  default = "PROJECT"
}

variable "enabled" {
  type    = bool
  default = true
}

variable "runbook_sync_enabled" {
  description = "When true, discovery ingests selected Datadog notebooks/workflows into Guild runbooks (requires at least one selector below)."
  type        = bool
  default     = false
}

variable "runbook_sync_notebook_ids" {
  description = "Comma-separated Datadog notebook IDs to sync (from SRE discovery report 'Available playbooks')."
  type        = string
  default     = ""
}

variable "runbook_sync_notebook_query" {
  description = "Substring match against notebook names when syncing runbooks."
  type        = string
  default     = ""
}

variable "runbook_sync_workflow_ids" {
  description = "Comma-separated Datadog workflow IDs to sync."
  type        = string
  default     = ""
}

variable "runbook_sync_workflow_query" {
  description = "Substring match against workflow names when syncing runbooks."
  type        = string
  default     = ""
}

variable "runbook_sync_knowledge_base_name" {
  description = "Guild knowledge base for ingested runbooks. Defaults to {integration_name}-playbooks when empty."
  type        = string
  default     = ""
}
