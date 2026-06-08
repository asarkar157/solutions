variable "name_suffix" {
  description = "Optional suffix appended to runbook SOP names."
  type        = string
  default     = ""
}

variable "org_baseline_name" {
  description = "Human-readable label for the organisation infrastructure baseline (e.g. acme-prod-baseline-v2)."
  type        = string
  default     = "organizational-baseline"
}

variable "fedramp_profile" {
  description = "FedRAMP baseline profile applied during contextual compliance (e.g. moderate, high)."
  type        = string
  default     = "moderate"
}

variable "knowledge_base_path" {
  description = "Repo or catalog path to hardened IaC knowledge base snippets (secure patterns, approved modules)."
  type        = string
  default     = "cloudformation/knowledge-base/"
}

variable "deployment_process_doc" {
  description = "Plain-language summary of the org deployment mechanism (PR approvals, change windows, pipeline names)."
  type        = string
  default     = "All infrastructure changes require GitHub PR review, cfn-lint/validate pass, and optional change-set preview before merge."
}

variable "cfn_template_catalog_path" {
  description = "Path to company CloudFormation template catalog for baseline alignment checks."
  type        = string
  default     = "cloudformation/catalog/"
}
