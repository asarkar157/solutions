Parse drift management scope from chat, webhook, or scheduled prompt.

**Default workspace:** `${workspace_id}` — repository `${workspace_repository}`, self_healing_allowed=${workspace_self_healing_allowed}.

1. Use upstream `stack_names` and `region` when normalize-drift-ingress already flattened webhook `drifted_stacks`.
2. Otherwise resolve regions (default ${default_aws_regions}), stack prefix allowlist, explicit stack names, environment tag filter.
3. Note `blocked:missing_drift_scope` when no region or filter is inferable.
4. Emit `drift_scope` JSON including `workspace_id`.
