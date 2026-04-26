output "agent_names" {
  value = { linear_planner = sg_agent.linear_planner.name, cursor_developer = sg_agent.cursor_developer.name }
}
