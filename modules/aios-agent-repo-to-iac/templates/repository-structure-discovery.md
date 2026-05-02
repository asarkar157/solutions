Parse GitHub repository structure and deployment signals.

## Steps

1. Parse `github_repo_url` into owner/repo
2. Resolve default branch
3. List tree for Dockerfile, compose, Kubernetes manifests, workflows, Terraform
4. Summarize runtime and deployment signals
