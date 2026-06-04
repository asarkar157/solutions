# IaC Drift Detective

An AI Agent acting as a CloudOps engineer dedicated to detecting, analyzing, and automatically reconciling configuration drift between cloud environments (AWS, GCP) and Infrastructure as Code repositories (Terraform/OpenTofu).

## Optional remote runner (StackGen provider >= 0.1.17)

Set `create_remote_runner = true` and `remote_runner_name` to register `sg_remote_runner` (provider **>= 0.1.25**) and copy **`remote_runner_helm_install_command`** / **`remote_runner_cli_start_command`** from outputs to deploy aiden-runner on-prem (outbound-only to mothership). Set `remote_runner_attach_to_agent = true` once the runner is online. Or omit `create_remote_runner` and only attach to an existing runner name.
