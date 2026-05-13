output "next_steps" {
  description = "Baseline applied. The tenant is now at: foundation + policies only."
  value       = <<-EOT

    Baseline applied. The tenant now has:
      - LLM secrets + models     (${jsonencode(module.foundation.model_names)})
      - Standard guardrail policies

    To wipe the prior demo's resources first, use:
      make demo-reset SCENARIO=<previous-scenario>
    then re-apply this baseline:
      make demo SCENARIO=clean-tenant-reset

  EOT
}

output "model_names" {
  value = module.foundation.model_names
}

output "policy_names" {
  value = module.policies.policy_names
}
