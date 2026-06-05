# Aiden Remote Runner on Amazon EKS — Terraform IaC

Provisions a **new private Kubernetes cluster** in your AWS account and installs one or more **StackGen Aiden Remote Runner** Helm agents. Each runner stays inside your VPC and connects **outbound** to the StackGen mothership, giving Aiden access to internal databases, MCP servers, APIs, and tools without exposing them to the public internet.

Based on [StackGen Remote Runners](https://docs.stackgen.com/aiden/settings/runners) and [Kubernetes integration](https://docs.stackgen.com/aiden/kubernetes).

---

## Architecture

```
StackGen mothership (HTTPS outbound)
        ▲
        │  STACKGEN_RUNNER_TOKEN + SERVER_URL
        │
┌───────┴────────────────────────────────────────┐
│  VPC (vpc_cidr)                                │
│  ├─ Public subnets  — NAT gateway, ELB         │
│  ├─ Private subnets — EKS worker nodes         │
│  │     ├─ Namespace: runner-main               │
│  │     │     └─ Pod: aiden-remote-runner       │
│  │     └─ Namespace: runner-secondary (opt.)   │
│  │           └─ Pod: aiden-remote-runner       │
│  └─ EKS control plane                         │
└────────────────────────────────────────────────┘
```

| Component | Purpose |
|-----------|---------|
| VPC + NAT | Worker nodes in **private subnets**; outbound-only path to mothership and image registry |
| EKS | New Kubernetes cluster dedicated to runner workloads |
| Helm | One `aiden-remote-runner` release per entry in `aiden_runner_tokens` |

---

## Prerequisites

- AWS credentials with permissions for VPC, EKS, IAM, and EC2
- Terraform >= 1.5
- `kubectl` and `helm` CLI (for post-deploy verification)

---

## Quick start

### 1. Create runner tokens in StackGen

Go to **StackGen → Settings → Remote Runners → Create New Runner** and copy the token for each runner you want to deploy.

### 2. Configure `terraform.tfvars`

```bash
cp terraform.tfvars.example terraform.tfvars
```

At minimum, set the required values (everything else has a working default):

```hcl
# One entry per runner — key = Helm release name = Kubernetes namespace
aiden_runner_tokens = {
  "runner-main" = "sg_aios_YOUR_TOKEN_HERE"
}

# Get the latest image version from:
# https://github.com/appcd-dev/stackgen-guild-aiden-runner/releases
aiden_runner_image_name    = "ghcr.io/appcd-dev/stackgen-guild-aiden-runner"
aiden_runner_image_version = "v0.1.34"
```

### 3. Deploy (15–20 minutes first run)

```bash
terraform init
terraform apply
```

### 4. Configure kubectl

Use the helper script (reads the access role ARN from Terraform state):

```bash
chmod +x scripts/configure-kubeconfig.sh
./scripts/configure-kubeconfig.sh
```

Or run the command from Terraform output directly:

```bash
$(terraform output -raw configure_kubectl)
```

> **SSO / AssumeRole troubleshooting:** If `terraform output` returns garbled text, you are in the wrong directory or state is missing. Run from `aiden-k8s-runner-iac/` after `terraform apply`. SSO sessions return `sts:assumed-role` ARNs — this module resolves them automatically to the underlying IAM role ARN (`issuer_arn`) so the trust policy stays valid.

### 5. Verify runners are online

```bash
# Show kubectl commands for all deployed runners
terraform output verify_runner_pods
terraform output verify_runner_logs
```

Then confirm each runner shows **Online** in **StackGen → Settings → Remote Runners** and enable **Use Remote Runner** on your integrations.

---

## Adding a second runner

Add a second entry to `aiden_runner_tokens` in `terraform.tfvars` and re-apply. No other changes required — every runner shares the same image, mothership URL, and chart settings.

```hcl
aiden_runner_tokens = {
  "runner-main"      = "sg_aios_TOKEN_ONE"
  "runner-secondary" = "sg_aios_TOKEN_TWO"
}
```

Each key becomes an independent Helm release deployed into its own Kubernetes namespace (named after the key). All runners are installed to the same EKS cluster.

---

## Variables reference

All variables are set in `terraform.tfvars`. Copy `terraform.tfvars.example` as a starting point — every variable is documented there with valid values and examples.

### AWS & Deployment Identity

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `aws_region` | | `us-east-1` | AWS region for all resources |
| `project_name` | | `aiden-k8s` | Prefix used in every resource name |
| `environment` | | `dev` | Environment label (`dev`, `staging`, `prod`, …) |

### Networking (VPC)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `vpc_cidr` | | `10.2.0.0/16` | IPv4 CIDR for the new VPC |
| `availability_zone_count` | | `2` | AZs to spread subnets across (2 or 3) |

### EKS Cluster

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `kubernetes_version` | | `1.30` | EKS control plane version (e.g. `1.30`, `1.31`) |
| `cluster_endpoint_private_access` | | `true` | Private API server endpoint (keep enabled) |
| `cluster_endpoint_public_access` | | `true` | Public API server endpoint (disable for fully private clusters) |

### Node Group (Worker Nodes)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `node_instance_types` | | `["t3.medium"]` | EC2 instance types in preference order |
| `node_capacity_type` | | `ON_DEMAND` | `ON_DEMAND` or `SPOT` |
| `node_desired_size` | | `2` | Target node count |
| `node_min_size` | | `1` | Minimum node count |
| `node_max_size` | | `3` | Maximum node count |
| `node_disk_size_gb` | | `50` | Root EBS volume size per node (GiB, min 20) |

### Aiden Remote Runners

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `aiden_runner_tokens` | **yes** | — | `map(string)` — each key defines one runner (name + namespace); value is its token (sensitive) |
| `aiden_runner_image_name` | **yes** | — | Container image repository for all runners |
| `aiden_runner_image_version` | **yes** | — | Pinned image tag — `latest` is rejected |
| `aiden_mothership_url` | | `https://main.dev.stackgen.com` | StackGen URL all runners register with |
| `aiden_auto_discover` | | `true` | Auto-register integrations and tools on startup |
| `aiden_stackgen_url` | | `""` | Override `STACKGEN_URL` independently (empty = use `aiden_mothership_url`) |
| `aiden_server_url` | | `""` | Override `SERVER_URL` explicitly (empty = derive from mothership) |
| `aiden_server_url_append_ai` | | `false` | Append `/ai` to mothership URL for `SERVER_URL` (StackGen Cloud) |
| `aiden_runner_chart_repository` | | `https://registry.devopsnow.io/chartrepo/public` | Helm chart repository |
| `aiden_runner_chart_name` | | `aiden-remote-runner` | Helm chart name |
| `aiden_runner_helm_timeout` | | `600` | Seconds to wait for Helm release readiness (60–1800) |

### EKS Cluster Access (IAM)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `eks_access_trusted_principal_arns` | | `[]` | Extra IAM role/user ARNs that may run `kubectl`. The Terraform caller is always included automatically. |
| `eks_cluster_access_policy_arn` | | `AmazonEKSClusterAdminPolicy` | EKS access policy for the kubectl IAM role. Use `AmazonEKSViewPolicy` for read-only. |

---

## How Terraform maps variables to Helm

For each entry in `aiden_runner_tokens`, Terraform runs the equivalent of:

```bash
helm upgrade --install <runner-name> aiden-remote-runner \
  --repo https://registry.devopsnow.io/chartrepo/public \
  -n <runner-name> --create-namespace \
  --set remote-runner.configMap.STACKGEN_RUNNER_TOKEN=<token> \
  --set remote-runner.configMap.STACKGEN_URL=<aiden_mothership_url> \
  --set remote-runner.configMap.RUNNER_ID=<token> \
  --set remote-runner.configMap.SERVER_URL=<derived-server-url> \
  --set remote-runner.configMap.AUTO_DISCOVER=true \
  --set remote-runner.image.repository=<aiden_runner_image_name> \
  --set remote-runner.image.tag=<aiden_runner_image_version>
```

The `configMap` keys are mounted as container environment variables via `envFrom`.

| tfvars variable | Helm configMap key | Runner env var |
|-----------------|-------------------|----------------|
| `aiden_runner_tokens[name]` | `STACKGEN_RUNNER_TOKEN` | token for runner registration |
| `aiden_mothership_url` | `STACKGEN_URL` | mothership base URL |
| `aiden_runner_tokens[name]` | `RUNNER_ID` | legacy token (older images) |
| derived from mothership | `SERVER_URL` | AI endpoint |
| `aiden_auto_discover` | `AUTO_DISCOVER` | auto-register integrations |

**`SERVER_URL` derivation** (in order of precedence):
1. `aiden_server_url` if explicitly set
2. `aiden_mothership_url + "/ai"` if `aiden_server_url_append_ai = true`
3. `aiden_mothership_url` (default)

---

## Outputs

After `terraform apply`, useful outputs include:

**Cluster**

| Output | Description |
|--------|-------------|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | EKS API server endpoint URL |
| `vpc_id` | ID of the VPC created for the cluster |

**kubectl access**

| Output | Description |
|--------|-------------|
| `configure_kubectl` | Full `aws eks update-kubeconfig` command — run or copy-paste to merge kubeconfig |
| `configure_kubectl_script` | Path to `scripts/configure-kubeconfig.sh` which validates the role ARN first |
| `eks_cluster_access_role_arn` | IAM role ARN to pass as `--role-arn` to `aws eks update-kubeconfig` |
| `eks_cluster_access_role_name` | IAM role name (useful for AWS Console lookups) |
| `eks_access_trusted_principals` | IAM principals currently allowed to assume the access role |
| `assume_eks_access_role_command` | `aws sts assume-role` command to assume the role directly into your shell |

**Runners**

| Output | Description |
|--------|-------------|
| `aiden_runner_namespaces` | Map of runner name → Kubernetes namespace |
| `aiden_runner_image` | `repository:tag` deployed to all runners |
| `aiden_server_url` | Resolved `SERVER_URL` passed to the Helm chart |
| `verify_runner_pods` | Map of `kubectl get pods` commands per runner |
| `verify_runner_logs` | Map of `kubectl logs` commands per runner |
| `helm_release_statuses` | Map of `helm status` commands per runner |

---

## Tear down

```bash
terraform destroy
```

Removes all Helm releases, the EKS cluster, NAT gateway, subnets, and VPC.

---

## Related module

For a **non-Kubernetes** runner using the `aiden-runner` CLI on an EC2 instance, see `../sre-runner-iac/`.
