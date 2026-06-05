# ─────────────────────────────────────────────────────────────────────────────
# AWS & Deployment Identity
# ─────────────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region where the EKS cluster and all supporting resources will be created (e.g. us-east-1, eu-west-1, ap-southeast-1)."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier (e.g. us-east-1, eu-west-1, ap-southeast-1)."
  }
}

variable "project_name" {
  description = "Short identifier used as a prefix in all resource names and tags (e.g. aiden-k8s). Lowercase letters, digits, and hyphens only — max 24 characters."
  type        = string
  default     = "aiden-k8s"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,23}$", var.project_name))
    error_message = "project_name must start with a letter, contain only lowercase letters, digits, and hyphens, and be at most 24 characters."
  }
}

variable "environment" {
  description = "Deployment environment label applied to resource names and tags (e.g. dev, staging, prod). Lowercase letters, digits, and hyphens — max 16 characters."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,15}$", var.environment))
    error_message = "environment must start with a letter, use only lowercase letters/digits/hyphens, and be at most 16 characters."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Networking (VPC)
# ─────────────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the new VPC (e.g. 10.2.0.0/16). Must be large enough for public and private subnets across all availability zones."
  type        = string
  default     = "10.2.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "availability_zone_count" {
  description = "Number of Availability Zones to spread subnets and worker nodes across. 2 is the minimum for high availability; 3 adds further resilience at slightly higher NAT/EIP cost."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be 2 or 3."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Cluster
# ─────────────────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane (e.g. 1.30, 1.31). AWS supports the last three minor versions. Check https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html for current options."
  type        = string
  default     = "1.30"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must be a MAJOR.MINOR string (e.g. 1.29, 1.30, 1.31)."
  }
}

variable "cluster_endpoint_private_access" {
  description = "Enable the private EKS API server endpoint so worker nodes communicate with the control plane within the VPC without leaving AWS. Strongly recommended to keep enabled."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Expose the EKS API server on the public internet. Required for kubectl access from outside the VPC (e.g. your laptop or CI). Set to false for fully private clusters that use a VPN or bastion host."
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# Node Group (Worker Nodes)
# ─────────────────────────────────────────────────────────────────────────────

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group, in preference order. The runner requires at least 2 vCPU and 4 GiB RAM — t3.medium (2 vCPU / 4 GiB) is the minimum. Larger instances (t3.large, m5.large) improve throughput for concurrent jobs."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "EC2 purchasing model for worker nodes. ON_DEMAND provides stable, uninterrupted capacity. SPOT can reduce costs by up to 90% but nodes may be reclaimed with 2 minutes notice — suitable for stateless runner workloads that can tolerate restarts."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_desired_size" {
  description = "Target (desired) number of worker nodes EKS maintains during normal operation. Must be between node_min_size and node_max_size. Start with 2 for redundancy."
  type        = number
  default     = 2

  validation {
    condition     = var.node_desired_size >= 1
    error_message = "node_desired_size must be at least 1."
  }
}

variable "node_min_size" {
  description = "Minimum number of worker nodes. The cluster will never scale below this value. Set to 1 to allow full scale-down; set to 2 for always-on redundancy."
  type        = number
  default     = 1

  validation {
    condition     = var.node_min_size >= 1
    error_message = "node_min_size must be at least 1."
  }
}

variable "node_max_size" {
  description = "Maximum number of worker nodes the cluster autoscaler may provision. Set high enough to absorb burst traffic without manually editing this value."
  type        = number
  default     = 3

  validation {
    condition     = var.node_max_size >= 1
    error_message = "node_max_size must be at least 1."
  }
}

variable "node_disk_size_gb" {
  description = "Root EBS volume size in GiB attached to each worker node. 50 GiB is recommended for runner workloads that pull container images and write temporary artifacts. Minimum 20 GiB."
  type        = number
  default     = 50

  validation {
    condition     = var.node_disk_size_gb >= 20
    error_message = "node_disk_size_gb must be at least 20 GiB."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Aiden Remote Runners — StackGen Helm Chart (one or more)
# ─────────────────────────────────────────────────────────────────────────────

variable "aiden_runner_tokens" {
  description = <<-EOT
    Runner authentication tokens keyed by runner name. Each key defines one runner
    deployment — the key becomes the Helm release name and the Kubernetes namespace.
    Add multiple entries to install several runners on the same cluster.
    Obtain each token from StackGen → Settings → Remote Runners → Create New Runner.
    Example: { "runner-prod" = "sg_aios_xxx...", "runner-dev" = "sg_aios_yyy..." }
  EOT
  type      = map(string)
  sensitive = true
}

variable "aiden_mothership_url" {
  description = "StackGen mothership URL all runners connect to (STACKGEN_URL / SERVER_URL base). Use https://main.dev.stackgen.com for StackGen Cloud; replace with your self-hosted URL if applicable."
  type        = string
  default     = "https://main.dev.stackgen.com"

  validation {
    condition     = can(regex("^https?://", var.aiden_mothership_url))
    error_message = "aiden_mothership_url must begin with http:// or https://."
  }
}

variable "aiden_stackgen_url" {
  description = "Override STACKGEN_URL independently from aiden_mothership_url. Leave empty to use aiden_mothership_url for both STACKGEN_URL and SERVER_URL."
  type        = string
  default     = ""
}

variable "aiden_server_url" {
  description = "Explicit SERVER_URL for the Helm chart. Leave empty to derive from aiden_mothership_url (appending /ai when aiden_server_url_append_ai is true)."
  type        = string
  default     = ""
}

variable "aiden_server_url_append_ai" {
  description = "When true and aiden_server_url is empty, SERVER_URL is set to aiden_mothership_url + '/ai'. Enable for StackGen Cloud deployments that route AI traffic through the /ai path."
  type        = bool
  default     = false
}

variable "aiden_auto_discover" {
  description = "Set AUTO_DISCOVER=true in every runner pod. When enabled, runners automatically scan and register available integrations, MCP servers, and tools with StackGen on startup."
  type        = bool
  default     = true
}

variable "aiden_runner_image_name" {
  description = "Container image repository for all runners (Helm: remote-runner.image.repository). Example: ghcr.io/appcd-dev/stackgen-guild-aiden-runner"
  type        = string
}

variable "aiden_runner_image_version" {
  description = "Pinned image tag for all runners (Helm: remote-runner.image.tag). Must be a specific release tag — 'latest' is rejected."
  type        = string

  validation {
    condition     = lower(var.aiden_runner_image_version) != "latest"
    error_message = "aiden_runner_image_version must be a pinned release tag (e.g. v0.1.34), not 'latest'."
  }
}

variable "aiden_runner_chart_repository" {
  description = "Helm repository URL hosting the aiden-remote-runner chart. Change only if you mirror the chart to an internal registry."
  type        = string
  default     = "https://registry.devopsnow.io/chartrepo/public"
}

variable "aiden_runner_chart_name" {
  description = "Helm chart name to install."
  type        = string
  default     = "aiden-remote-runner"
}

variable "aiden_runner_helm_timeout" {
  description = "Maximum seconds Terraform waits for each Helm release to reach a ready state. Increase on slow networks or first deploys. Range: 60–1800 seconds."
  type        = number
  default     = 600

  validation {
    condition     = var.aiden_runner_helm_timeout >= 60 && var.aiden_runner_helm_timeout <= 1800
    error_message = "aiden_runner_helm_timeout must be between 60 and 1800 seconds."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Cluster Access (IAM Role for kubectl / AWS CLI)
# ─────────────────────────────────────────────────────────────────────────────

variable "eks_access_trusted_principal_arns" {
  description = <<-EOT
    Additional IAM principal ARNs (users or roles) permitted to assume the EKS kubectl access role.
    The IAM identity that ran terraform apply is always trusted automatically via its issuer ARN.
    Add CI/CD role ARNs or teammate role ARNs here.
    Use full IAM role ARNs (arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME) — sts:assumed-role session ARNs are not valid in trust policies.
    Example: ["arn:aws:iam::123456789012:role/my-admin-role", "arn:aws:iam::123456789012:user/alice"]
  EOT
  type    = list(string)
  default = []
}

variable "eks_cluster_access_policy_arn" {
  description = "AWS-managed EKS access policy attached to the kubectl IAM role. AmazonEKSClusterAdminPolicy grants full cluster admin. Use AmazonEKSViewPolicy for read-only access (e.g. for auditors)."
  type        = string
  default     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  validation {
    condition     = can(regex("^arn:aws:eks::aws:cluster-access-policy/", var.eks_cluster_access_policy_arn))
    error_message = "eks_cluster_access_policy_arn must be a valid EKS cluster access policy ARN (arn:aws:eks::aws:cluster-access-policy/...)."
  }
}
