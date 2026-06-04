# Per-stage hypothesis subagent spawn contracts for ReAcTree cross-signal-investigate.

locals {
  hypothesis_spawn_context = <<-EOT
workflow_run_id: {{workflow_run_id}}
WORK_ROOT: {{work_root}}
Investigation window: ±15 minutes around normalized_alert.fired_at.
Read normalized_alert, grafana_query_probe, prior_incidents, k8s_context from read_notes before tool use.
Emit hypothesis_result JSON only — do not post to Slack.
EOT

  hypothesis_common_tools = compact([
    "note",
    "read_notes",
    trimspace(local.resolved_grafana_integration_name) != "" ? "${local.grafana_tool_prefix}_get_alert_rule" : "",
    trimspace(local.resolved_grafana_integration_name) != "" ? "${local.grafana_tool_prefix}_list_firing_instances" : "",
    trimspace(local.resolved_grafana_integration_name) != "" ? "${local.grafana_tool_prefix}_query_metric" : "",
    trimspace(local.resolved_grafana_integration_name) != "" ? "${local.grafana_tool_prefix}_execute_command" : "",
    trimspace(local.resolved_github_integration_name) != "" ? "${local.github_tool_prefix}_execute_command" : "",
    trimspace(local.resolved_github_integration_name) != "" ? "${local.github_tool_prefix}_execute_series" : "",
    trimspace(local.resolved_aws_integration_name) != "" ? "${local.aws_tool_prefix}_execute_command" : "",
    trimspace(local.resolved_aws_integration_name) != "" ? "${local.aws_tool_prefix}_execute_series" : "",
  ])

  spawn_contract_hypothesis_deploy = {
    sub_agent_name      = "hypothesis-deploy-regression"
    task_type           = "efficiency"
    tool_names          = local.hypothesis_common_tools
    max_llm_calls       = 12
    max_tool_iterations = 35
    timeout_seconds     = 600
    goal                = "Test deploy-regression hypothesis for the Grafana alert. Correlate GitHub commits and AWS ECS/CloudTrail deploy events in the investigation window with grafana_query_probe signals. Emit hypothesis_result JSON with confidence and evidence_links. Read-only — no mutations."
    context             = local.hypothesis_spawn_context
  }

  spawn_contract_hypothesis_capacity = {
    sub_agent_name      = "hypothesis-capacity"
    task_type           = "efficiency"
    tool_names          = local.hypothesis_common_tools
    max_llm_calls       = 12
    max_tool_iterations = 35
    timeout_seconds     = 600
    goal                = "Test capacity/saturation hypothesis. Use query_metric for CPU/memory/thread pool saturation scoped to alert labels; include k8s_context when present. Emit hypothesis_result JSON. Read-only."
    context             = local.hypothesis_spawn_context
  }

  spawn_contract_hypothesis_config = {
    sub_agent_name      = "hypothesis-config-drift"
    task_type           = "efficiency"
    tool_names          = local.hypothesis_common_tools
    max_llm_calls       = 12
    max_tool_iterations = 35
    timeout_seconds     = 600
    goal                = "Test config-drift hypothesis. Inspect CloudTrail IAM/config changes and recent GitHub commits affecting config paths. Emit hypothesis_result JSON. Read-only."
    context             = local.hypothesis_spawn_context
  }

  spawn_contract_hypothesis_dependency = {
    sub_agent_name      = "hypothesis-dependency"
    task_type           = "efficiency"
    tool_names          = local.hypothesis_common_tools
    max_llm_calls       = 12
    max_tool_iterations = 35
    timeout_seconds     = 600
    goal                = "Test upstream dependency failure hypothesis. Correlate co-firing Grafana alerts and trace/service hints with grafana_signals. Emit hypothesis_result JSON. Read-only."
    context             = local.hypothesis_spawn_context
  }

  spawn_contract_hypothesis_network = {
    sub_agent_name      = "hypothesis-network-topology"
    task_type           = "efficiency"
    tool_names          = local.hypothesis_common_tools
    max_llm_calls       = 12
    max_tool_iterations = 35
    timeout_seconds     = 600
    goal                = "Test network/topology hypothesis. Review alert labels for network/infra scope; use AWS read-only snapshots when wired and Grafana co-firing groups. Emit hypothesis_result JSON. Read-only."
    context             = local.hypothesis_spawn_context
  }

  spawn_contracts_hypothesis_tree = [
    local.spawn_contract_hypothesis_deploy,
    local.spawn_contract_hypothesis_capacity,
    local.spawn_contract_hypothesis_config,
    local.spawn_contract_hypothesis_dependency,
    local.spawn_contract_hypothesis_network,
  ]
}
