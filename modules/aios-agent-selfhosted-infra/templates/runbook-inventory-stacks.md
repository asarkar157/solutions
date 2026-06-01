Inventory CloudFormation stacks across configured regions for drift audit.

## Steps

1. For each region in `${default_aws_regions}`, list stacks with `list-stacks` (active and failed statuses).
2. Filter stacks by configured prefix allowlist when set.
3. Capture stack name, status, creation time, last updated time, and environment tag.
4. Emit `stack_inventory` JSON with per-region stack lists and summary counts.

## Guardrails

- Read-only inventory — no stack mutations.
