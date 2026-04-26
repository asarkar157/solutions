variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string })
}
variable "policy_ids" {
  type = object({
    dangerous_ops        = string
    container_shell_hitl = string
  })
}
variable "integration_names" {
  type = object({ ubuntu_cli = string })
}
