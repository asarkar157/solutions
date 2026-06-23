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

variable "sre_app_name" {
  description = "Deployment-catalog slug for the installed SRE Copilot app (data.sg_app lookup for existing integration bindings)."
  type        = string
  default     = "sre"
}

variable "existing_datadog_integration_name" {
  description = "Guild Datadog integration already provisioned during SRE app onboarding (data.sg_guild_integration lookup). Not created by this scenario."
  type        = string
  default     = "datadog"
}

# ----- Datadog (monitor scoping — integration comes from SRE app onboarding) --
variable "datadog_site" {
  description = "Datadog site code (us1, us3, us5, eu1, ap1, ap2) or full hostname. Used in outputs/README monitor guidance only."
  type        = string
  default     = "us3"
}

variable "tracked_service" {
  description = "Datadog APM service tag the demo tracks (order-service k8s/stack.yaml sets DD_SERVICE). Used in README monitor-scoping guidance, monitor tags for SRE discovery, and outputs."
  type        = string
  default     = "order-service"
}

variable "tracked_env" {
  description = "Datadog env tag the demo tracks (the aiden-demo workload's DD_ENV)."
  type        = string
  default     = "demo"
}

variable "tracked_namespace" {
  description = "Kubernetes namespace the aiden-demo workload + Datadog agent run in."
  type        = string
  default     = "aiden-demo"
}

# ----- AWS (optional) --------------------------------------------------------
variable "aws_role_arn" {
  description = "IAM role ARN the AWS integration assumes via Vault. Leave empty to skip AWS (Datadog + GitHub + SRE app bindings only)."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "Default AWS region for the AWS integration."
  type        = string
  default     = "us-east-1"
}

# ----- GitHub (required) -----------------------------------------------------
variable "github_token" {
  description = "GitHub personal access token (requires repo, read:org scopes). The investigator uses this to read repo context and to open the RCA fix PR."
  type        = string
  sensitive   = true
}

# ----- Slack (optional) ------------------------------------------------------
variable "slack_bot_token" {
  description = "Slack Bot Token. Optional: leave empty to skip the Slack integration (the agents still run in Guild chat; FinOps summary stays in Guild)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "gateway_base_url" {
  description = "Public Omnichannel Gateway origin (no trailing slash), e.g. https://gateway.example.com. When set, outputs include gateway_slack_event_url for Slack App Event Subscriptions."
  type        = string
  default     = ""
}

# ----- Cost wow factor toggle ------------------------------------------------
variable "enable_finops" {
  description = "Create the cost-optimizer agent + weekly FinOps cron for the cost-management wow factor. Set false to keep the demo focused on the Datadog RCA flow only."
  type        = bool
  default     = true
}

variable "finops_model_names" {
  description = "Guild-registered model names for the FinOps cost agent when enable_finops is true. Not used for the SRE investigator — models come from the stackgen-sre-app install or another foundation root."
  type        = list(string)
  default     = []
}

variable "enable_policies" {
  description = "Create aios-policies guardrails including sre-investigation-write-gate for HITL on Datadog writeback and GitHub fix PRs. Set false only when the org already attached equivalent policies."
  type        = bool
  default     = true
}

variable "enable_sre_app_bindings" {
  description = "Merge GitHub (and optional AWS / Slack) onto the installed stackgen-sre-app via sg_app. Requires the SRE app to already be installed."
  type        = bool
  default     = true
}

variable "enable_datadog_alert_webhook" {
  description = "When true (and enable_sre_app_bindings is true), register sg_sre_alert_webhook for Datadog ingest. Leave false when alert ingest was configured during SRE app onboarding."
  type        = bool
  default     = false
}

variable "datadog_alert_auto_investigate" {
  description = "When enable_datadog_alert_webhook is true, auto-start investigations on newly ingested Datadog alerts."
  type        = bool
  default     = false
}

# ----- Remote runner (optional) -----------------------------------------------
variable "create_remote_runner" {
  description = "Manage sg_remote_runner (register or look up) and bind Datadog/GitHub (and AWS when enabled) secrets for aiden-runner."
  type        = bool
  default     = true
}

variable "register_remote_runner" {
  description = "When true (and create_remote_runner is true), register a new sg_remote_runner. Set false to look up an existing runner by remote_runner_name — use after the runner already exists in Guild or when Create returns 429."
  type        = bool
  default     = true
}

variable "remote_runner_name" {
  description = "Guild remote runner name when create_remote_runner is true."
  type        = string
  default     = "datadog-aws-rca-runner"
}

variable "investigator_agent_name" {
  description = "SRE app investigator agent name (from stackgen-sre-app manifest). Attach remote runner after the app is installed."
  type        = string
  default     = "stackgen-sre-investigator"
}

variable "runner_docker_image" {
  description = "aiden-runner image for the Docker start command output."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-aiden-runner:main"
}

variable "service_repository_map" {
  description = <<-EOT
    Maps Datadog APM service names to GitHub repos for change correlation and closed-loop fix PRs.
    Values use "org/repo" or "org/repo:branch:path1,path2". Serialized into sg_app.config as
    service_repo_<service> keys for the stackgen-sre-app investigation context.
  EOT
  type        = map(string)
  default = {
    "order-service"           = "stackgen-demo/order-service:main:cmd/initdb/main.go,internal/handlers/orders.go"
    "payment-service"         = "stackgen-demo/payment-service:main:charge.js,k8s/stack.yaml"
    "product-catalog-service" = "stackgen-demo/product-catalog-service:main:main.go"
    "ad-service"              = "stackgen-demo/ad-service:main:src/main/java,k8s/deployment.yaml"
  }
}
