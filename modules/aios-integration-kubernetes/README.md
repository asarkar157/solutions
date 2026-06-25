# AIOS Integration — Kubernetes (EKS)

Provisions a Guild `kubernetes` integration for read-only EKS inspection via kubectl.

## Vault metadata

| Key | Required |
|-----|----------|
| `role_arn` | yes |
| `region` | yes |
| `cluster_name` | yes |

## Usage

```hcl
module "kubernetes" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-kubernetes?ref=main"

  role_arn     = var.eks_role_arn
  region       = "us-west-2"
  cluster_name = "my-cluster"
}
```
