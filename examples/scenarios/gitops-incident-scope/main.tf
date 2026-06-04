# gitops-incident-scope — GitOps SRE with CCE scoped rollback (PrivateSaaS profile).

# Requires GitLab, Argo CD, SonarQube, AWS, and Slack credentials.
# See modules/aios-agent-privatesaas-gitops-sre/README.md for full variable list.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

module "foundation" {
  source         = "../../../modules/aios-foundation"
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id
  llm_api_keys = {
    openai    = var.openai_api_key
    anthropic = var.anthropic_api_key
    gemini    = var.gemini_api_key
  }
}

module "policies" {
  source = "../../../modules/aios-policies"
}

module "gitops_sre" {
  source = "../../../modules/aios-agent-privatesaas-gitops-sre"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    sre_remediation = module.policies.policy_ids.sre_remediation
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  gitlab_secret_id    = var.gitlab_secret_id
  argocd_secret_id    = var.argocd_secret_id
  sonarqube_secret_id = var.sonarqube_secret_id
  aws_secret_id       = var.aws_secret_id
  slack_secret_id     = var.slack_secret_id

  enable_cce        = true
  enable_ubuntu_cli = true
  git_repo          = var.git_repo
}
