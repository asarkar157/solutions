# Inspect DynamoDB

Read-only AWS DynamoDB throttle and capacity review.

## Hints

- Tables: ${dynamodb_table_hints}
- Environment: ${private_saas_environment_label}

## Steps

1. Describe table status and consumed capacity for hinted tables.
2. Check throttling metrics and hot partition indicators around incident window.
3. Correlate with deploy timing from GitLab/Argo CD stages.
4. Emit `dynamodb_inspection` JSON.
