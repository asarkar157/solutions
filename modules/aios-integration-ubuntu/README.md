# AIOS Integration — Ubuntu CLI

Generic Ubuntu MCP shell for OS-level diagnostics (curl, ping, dig, journalctl, top, df, etc.)
with configurable tool installation at startup.

## Usage

```hcl
module "ubuntu_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-ubuntu"
}
```

### With startup tool installation

Install CLI tools (tofu, terraform, awscli, kubectl, helm, gcloud, az) when the
container boots — no need to bake a custom image:

```hcl
module "ubuntu_integration" {
  source        = "github.com/appcd-dev/solutions//modules/aios-integration-ubuntu"
  install_tools = ["tofu", "awscli", "kubectl"]
}
```

### With AWS credentials (for `tofu plan`, state backends)

Pass the vault secret IDs via `secret_ref_ids` so that the container launches with
AWS env-var auth (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`):

```hcl
resource "sg_secret" "ubuntu_aws" {
  name        = "ubuntu-cli-aws-vault"
  description = "AWS credentials for Ubuntu CLI container"
  category    = "CloudProvider"
  subcategory = "aws"
  metadata = {
    aws_role_arn = var.aws_role_arn
    aws_region   = "us-east-1"
  }
}

module "ubuntu_integration" {
  source         = "github.com/appcd-dev/solutions//modules/aios-integration-ubuntu"
  secret_ref_ids = [sg_secret.ubuntu_aws.id]
  install_tools  = ["tofu", "awscli"]
}
```

### With extra environment variables

```hcl
module "ubuntu_integration" {
  source        = "github.com/appcd-dev/solutions//modules/aios-integration-ubuntu"
  install_tools = ["tofu", "awscli"]
  env_vars = {
    AWS_DEFAULT_REGION = "us-west-2"
    TF_LOG             = "INFO"
  }
}
```

## Supported Tools

| Tool        | Value       | Description                    |
|-------------|-------------|--------------------------------|
| OpenTofu    | `tofu`      | OpenTofu (latest)              |
| Terraform   | `terraform` | HashiCorp Terraform (latest)   |
| AWS CLI     | `awscli`    | AWS CLI v2                     |
| kubectl     | `kubectl`   | Kubernetes CLI                 |
| Helm        | `helm`      | Helm package manager           |
| Google Cloud| `gcloud`    | Google Cloud SDK               |
| Azure CLI   | `az`        | Azure CLI                      |

## Variables

| Name               | Type           | Default                                                           | Description                                     |
|--------------------|----------------|-------------------------------------------------------------------|-------------------------------------------------|
| `integration_name` | `string`       | `"ubuntu-cli"`                                                    | Integration name                                |
| `integration_image`| `string`       | `"ghcr.io/appcd-dev/stackgen-guild-integration-ubuntu:main"`      | Container image                                 |
| `secret_ref_ids`   | `list(string)` | `[]`                                                              | Vault secret IDs to inject                      |
| `install_tools`    | `list(string)` | `[]`                                                              | CLI tools to install at startup (`tofu`, `terraform`, `awscli`, `kubectl`, `helm`, `gcloud`, `az`, `gh`, `git`, `curl`, `jq`, `gdown`, `cce`, `python3-pip`) |
| `env_vars`         | `map(string)`  | `{}`                                                              | Extra environment variables                     |
