output "runner_name" {
  description = "Guild remote runner name to pass to sg_agent.remote_runners."
  value       = local.runner_name
}

output "runner_id" {
  description = "Server-assigned runner ID."
  value       = local.runner_id
}

output "runner_status" {
  description = "Runner lifecycle status from Guild (online, offline, etc.)."
  value       = local.status
}

output "created" {
  description = "True when this apply registered a new sg_remote_runner (create_runner = true)."
  value       = var.create_runner
}

output "mothership_url" {
  description = "StackGen mothership base URL (provider stackgen_url). Empty when runner was only looked up, not created in this root."
  value       = ""
}
