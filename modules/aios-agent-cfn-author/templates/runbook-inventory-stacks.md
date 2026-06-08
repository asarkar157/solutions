Inventory CloudFormation stacks matching drift scope.

1. List stacks per configured region via AWS read-only APIs.
2. Filter by prefix allowlist and environment tag when configured.
3. Emit `stack_inventory` JSON and `stack_count`.
4. `note("stacks_inventoried", "true")` when inventory completes.
