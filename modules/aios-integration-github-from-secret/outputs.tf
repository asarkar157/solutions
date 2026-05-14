output "secret_id" {
  description = <<-EOT
    ID of the Provider/github `sg_secret`. Pass to agent modules as their
    `github_secret_id` input — the agent module forwards it to both its
    internal GitHub Guild integration (where the secret reader still finds a
    usable token in the metadata) and its internal Ubuntu integration's
    `secret_ref_ids` (where the pre_launch.sh script surfaces the
    `GIT_*` env vars).
  EOT
  value       = sg_secret.provider_github.id
  sensitive   = true
}

output "secret_name" {
  description = "Name of the Provider/github `sg_secret`."
  value       = sg_secret.provider_github.name
}
