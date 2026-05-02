output "schedule_ids" {
  description = "Map of schedule name → server-assigned schedule id."
  value       = { for k, v in sg_agent_schedule.this : k => v.id }
}

output "schedule_names" {
  description = "Schedule names managed by this module instance (set semantics)."
  value       = toset(keys(sg_agent_schedule.this))
}
