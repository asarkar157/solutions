Normalize an inbound CloudFormation stack failure payload (EventBridge, SNS, webhook JSON, or manual input) into a stable incident envelope for self-hosted infra triage.

## Steps

1. Parse the payload: stack name, stack ID, region, status, status reason, and resource status events.
2. Extract environment from stack tags using key `${stack_tags_environment_key}` (fallback: payload labels or annotations).
3. Map CloudFormation terminal failure states to an internal severity label.
4. Collect failed resource logical IDs and physical IDs from the most recent stack events.
5. Apply stack hints from configuration when the stack name matches a known hint entry.
6. Build a `normalized_stack_event` object with: `stack_name`, `stack_id`, `region`, `status`, `status_reason`, `failed_resources`, `environment`, `tags`, `event_time`, `source`.
7. Persist the normalized envelope as stage output JSON — downstream investigation stages consume this schema only.

## Guardrails

- Read-only during normalization; do not call mutating CloudFormation APIs.
- Default region to `${default_aws_regions}` when the payload omits region.
- Redact account IDs from shared summaries when policy requires.
- Assume self-hosted private AWS account — no public SaaS URLs.
