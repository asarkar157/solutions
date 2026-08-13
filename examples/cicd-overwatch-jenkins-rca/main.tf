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
}

variable "stackgen_url" {
  type = string
}

variable "stackgen_token" {
  type      = string
  sensitive = true
}

module "cicd_overwatch_jenkins_rca" {
  source = "../../modules/aios-agent-cicd-overwatch-jenkins-rca"

  model_names = ["openai-dell-sandbox-gpt-5.6-terra", "openai-dell-sandbox-gpt-5.5"]

  # Reuse the Jenkins and Linear integrations already registered in the POC StackGen project.
  existing_jenkins_integration_name = "jenkins"
  existing_linear_integration_name  = "devops-linear"
}

output "agent_name" {
  value = module.cicd_overwatch_jenkins_rca.agent_name
}

output "workflow_name" {
  value = module.cicd_overwatch_jenkins_rca.workflow_name
}

output "skill_names" {
  value = module.cicd_overwatch_jenkins_rca.skill_names
}

output "knowledge_base_id" {
  value = module.cicd_overwatch_jenkins_rca.knowledge_base_id
}

output "webhook_id" {
  value = module.cicd_overwatch_jenkins_rca.webhook_id
}
