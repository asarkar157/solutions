# AIOS Integration — GCP

Provisions Vault secret with GCP service account credentials and a containerized GCP MCP integration.

## Usage

```hcl
module "gcp_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-gcp"

  gcp_credentials_json = var.gcp_credentials_json
  gcp_project_id       = "my-project-id"
}
```
