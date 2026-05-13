# IaC Drift Detective

An AI Agent acting as a CloudOps engineer dedicated to detecting, analyzing, and automatically reconciling configuration drift between cloud environments (AWS, GCP) and Infrastructure as Code repositories (Terraform/OpenTofu).

## Optional remote runner (StackGen provider >= 0.1.13)

Set `remote_runner_name` and `remote_runner_attach_to_agent = true` to look up the runner with `data.sg_remote_runner` and set `sg_agent.remote_runners` on the drift agent so Guild may dispatch heavy plan work to your org runner. The runner must already exist; set provider `project_id` when the API is org-scoped.
