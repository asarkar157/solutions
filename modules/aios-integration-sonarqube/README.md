# AIOS Integration — SonarQube

Provisions a SonarQube Guild integration (`type = sonarqube`) for quality gate and branch analysis.

## Usage

```hcl
module "sonarqube_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-sonarqube?ref=main"

  server_url = "https://sonar.example.com"
  token      = var.sonarqube_token
}
```

Or bind an existing vault secret (metadata keys: `server_url`, `token`):

```hcl
module "sonarqube_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-sonarqube?ref=main"

  existing_secret_id = var.sonarqube_secret_id
}
```

## Catalog note

Confirm `sonarqube` is registered in your StackGen Guild integration catalog before apply.

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID bound to the integration |
