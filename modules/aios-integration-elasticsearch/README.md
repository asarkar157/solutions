# AIOS Integration — Elasticsearch

Provisions a `Database`/`elasticsearch` `sg_secret` and Guild `elasticsearch` MCP integration using the official [`@elastic/mcp-server-elasticsearch`](https://github.com/elastic/mcp-server-elasticsearch) sidecar.

## Vault metadata

| Key | Required | Description |
|-----|----------|-------------|
| `es_url` | yes | Cluster URL (`https://…:9200` or `http://…` for dev-only) |
| `es_api_key` | yes | Elasticsearch API key (vault rejects empty values) |
| `es_ssl_skip_verify` | no | Set to `true` only for lab clusters with self-signed TLS |

## Example

```hcl
module "elasticsearch" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-elasticsearch?ref=main"

  integration_name        = "prod-elasticsearch"
  elasticsearch_mcp_image = var.elasticsearch_mcp_image
  es_url                  = "https://elasticsearch.example.com:9200"
  es_api_key              = var.elasticsearch_api_key
}
```

Use `existing_secret_id` when the vault secret is managed elsewhere.
