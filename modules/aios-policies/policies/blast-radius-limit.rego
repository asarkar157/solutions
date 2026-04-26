package policy

default approval_required = false

max_pods_without_approval := 5
max_nodes_without_approval := 3

# kubectl scale/rollout restart targeting many replicas requires approval.
approval_required if {
	input.tool.name == "kubectl"
	input.tool.arguments.action in {"scale", "rollout"}
	input.tool.arguments.replicas > max_pods_without_approval
}

# kubectl drain/cordon on multiple nodes requires approval.
approval_required if {
	input.tool.name == "kubectl"
	input.tool.arguments.action in {"drain", "cordon", "taint"}
	input.tool.arguments.node_count > max_nodes_without_approval
}

# Shell commands with broad blast radius indicators require approval.
approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	broad_blast_shell(cmd)
}

broad_blast_shell(cmd) if {
	contains(cmd, "kubectl scale")
	contains(cmd, "--replicas=")
	not contains(cmd, "--replicas=1")
	not contains(cmd, "--replicas=2")
	not contains(cmd, "--replicas=3")
}

broad_blast_shell(cmd) if {
	contains(cmd, "kubectl drain")
	contains(cmd, "--selector")
}

broad_blast_shell(cmd) if {
	contains(cmd, "kubectl delete")
	contains(cmd, "--all")
}

# AWS operations spanning multiple regions require approval.
approval_required if {
	input.tool.name == "aws_cli"
	regions := object.get(input.tool.arguments, "regions", [])
	count(regions) > 1
}

# Context-graph enhanced: pod/node count from context graph.
approval_required if {
	input.context.target_pod_count > max_pods_without_approval
}

approval_required if {
	input.context.target_node_count > max_nodes_without_approval
}

approval_reason = "Blast radius exceeds safe threshold — must target ≤ 5 pods / ≤ 3 nodes / single region without approval" if {
	approval_required
}
