# integration-gaps-smoke

Terraform scenario for the nine Aiden-2 integration gap types: `kubernetes`, `sonarqube`, `firehydrant`, `digitalocean`, `coralogix`, `civo`, `newrelic`, `circleci`, `squadcast`.

## Quick start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit tfvars: stackgen_url, stackgen_token, enable_* flags and credentials

tofu init
tofu apply

export STACKGEN_TOKEN="..."
./scripts/verify-catalog.sh
./scripts/test-integrations.sh
```

## Prerequisites

- Guild dev-edge on `:8088` (or staging) with integration sidecar images available on GHCR `:main`
- Vault subcategories for `civo`, `newrelic`, `circleci`, `squadcast` deployed (stackgen-vault)
