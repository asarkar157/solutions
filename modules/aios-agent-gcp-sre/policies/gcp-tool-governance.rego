package policy

default approval_required = false

# Gate destructive GCP operations
approval_required if {
	endswith(input.tool.name, "_execute_command")
	cmd := lower(input.tool.arguments.command)
	gcp_destructive_pattern(cmd)
}

gcp_destructive_pattern(cmd) if contains(cmd, "gcloud compute instances delete")
gcp_destructive_pattern(cmd) if contains(cmd, "gcloud container clusters delete")
gcp_destructive_pattern(cmd) if contains(cmd, "gcloud sql instances delete")
gcp_destructive_pattern(cmd) if contains(cmd, "gcloud storage rm")
gcp_destructive_pattern(cmd) if contains(cmd, "gsutil rm")
gcp_destructive_pattern(cmd) if contains(cmd, "gcloud projects delete")
gcp_destructive_pattern(cmd) if contains(cmd, "gcloud iam service-accounts delete")
gcp_destructive_pattern(cmd) if contains(cmd, "kubectl delete")
gcp_destructive_pattern(cmd) if contains(cmd, "gcloud run services delete")

approval_reason = "Destructive GCP operation requires human approval" if {
	approval_required
}
